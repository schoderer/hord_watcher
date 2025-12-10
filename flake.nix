{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
    crane.url = "github:ipetkov/crane";
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Import packages with overlay
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        # Configure the rust toolchain
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          targets = [ "x86_64-unknown-linux-musl" ];
          extensions = [ "rust-analyzer" "rust-src" "clippy" "rustfmt" ];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        src = craneLib.cleanCargoSource ./.;

        ##########
        # Required Packages
        ##########
        args = {
          nativeBuildInputs = with pkgs; [ rustToolchain pkg-config ];
          buildInputs = with pkgs; [ openssl ];
          inherit src;
          strictDeps = true;
          CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
          CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
        };

        cargoArtifacts = craneLib.buildDepsOnly args;
        bin = craneLib.buildPackage (args // { inherit cargoArtifacts; });

        ##########
        # Dockerimage
        ##########
        # Example for adding a file to the image. Add this to the copyToRoot
        # baseConfigFile = pkgs.writeTextDir "/config_base.toml" (builtins.readFile ./config_base.toml);

        dockerImage = pkgs.dockerTools.buildImage {
          name = "ghcr.io/schoderer/hord_watcher";
          tag = "latest";
          created = "now"; # Breaks binary reproducable, but creation is not epoch

          #copyToRoot = [ bin ];
          config = {
            Cmd = [ "${bin}/bin/hord_watcher" ];
            User = "7337:7337"; # Run this not as root
            Env = [];
          };
        };
      in with pkgs; {
        packages = {
          inherit bin dockerImage;
          default = bin;
        };
        devShells.default = mkShell {
          nativeBuildInputs = args.nativeBuildInputs;
          buildInputs = args.buildInputs;
        };
      }
    );
}
