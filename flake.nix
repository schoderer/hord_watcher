# in flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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
          rustToolchain = pkgs.rust-bin.stable.latest.default;
          craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
          src = craneLib.cleanCargoSource ./.;          
          args = {
            nativeBuildInputs = with pkgs; [ rustToolchain pkg-config ];
            buildInputs = with pkgs; [ openssl ];
            inherit src;
          };
          cargo-clippy = craneLib.cargoClippy {
            inherit cargoArtifacts src;
            cargoClippyExtraArgs = "-- --deny warnings";
          };
          cargoArtifacts = craneLib.buildDepsOnly args;
          bin = craneLib.buildPackage (args // {
            inherit cargoArtifacts;
          });
          dockerImage = pkgs.dockerTools.buildImage {
            name = "ghcr.io/schoderer/hord_watcher";
            tag = "latest";
            copyToRoot = [ bin ];
            config = {
              Cmd = [ "${bin}/bin/hord_watcher" ];
            };
          };
        in
        with pkgs;
        {
          checks = {
            inherit bin cargo-clippy;
          };
          packages =
            {
              inherit bin dockerImage;
              default = bin;
            };
          devShells.default = mkShell {
            inputsFrom = [ bin ];
          };
        }
      );
}