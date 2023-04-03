{
  description = "Namespace-Controller-Server";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        rust-overlay.follows = "rust-overlay";
      };
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };


          rustToolchain = pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" ];
          };
          nativeBuildInputs = with pkgs; [ rustToolchain pkg-config ];
          craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
          src = craneLib.cleanCargoSource ./.;
          commonArgs = {
            inherit src buildInputs nativeBuildInputs;
          };
          buildInputs = with pkgs; [ openssl ];
          bin = craneLib.buildPackage (commonArgs);
          dockerImage = pkgs.dockerTools.buildImage {
            name = "namespace_controller";
            tag = "latest";
            copyToRoot = [ bin ];
            config = {
              Cmd = [ "${bin}/bin/namespace_controller" ];
            };
          };
        in
        with pkgs;
        {
          packages = {
            inherit bin dockerImage;
            default = bin;
          };
          devShells.default = mkShell
            {
              inputsFrom = [ bin ];
            };
        }
      );

}
