{
  description = "A deterministic, pure VM generator utilizing Nix and Packer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Flake utilities
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Expose the library as a callable function for downstream consumers
      flake.lib = import ./lib;

      # Overlay adding the helper functions to pkgs.*
      flake.overlays.default =
        prev: next:
        builtins.mapAttrs (name: value: value) self.lib {
          pkgs = prev;
          lib = prev.lib;
          stdenv = prev.stdenv;
        };

      perSystem =
        {
          config,
          lib,
          system,
          ...
        }:
        let
          # Instantiate Nixpkgs and allow Packer installation
          pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (lib.getName pkg) [
                "packer"
                "windows"
              ];
          };

          # Instantiate DVM libraries with current system's pkgs
          vmLib = inputs.self.lib {
            inherit pkgs;
            inherit (pkgs) lib stdenv;
          };

          # Define standard plugins using the library helper
          qemuPlugin = vmLib.mkPackerPlugin {
            name = "qemu";
            version = "1.1.6";
            hash = "sha256-m5TExlmdPxKnp45SjheMggnUNo1D3KMr+uV1zC2f3Ts=";
            binaries = with pkgs; [
              qemu_kvm
              cdrtools
            ];
          };
        in
        rec {
          # Configure Nix syntax formatting
          treefmt.programs.nixfmt = {
            enable = true;

            # Enfore strict style
            indent = 2;
            width = 100;
          };

          # Package Packer and examples into a devShell
          devShells.default = pkgs.mkShell {
            packages = builtins.attrValues packages;
          };

          packages =
            let
              examples = pkgs.callPackage ./examples { inherit vmLib qemuPlugin; };
            in
            {
              # Include example builders
              inherit (examples)
                nixos
                nixos-debug
                ubuntu
                ubuntu-debug
                windows
                windows-debug
                ;

              # Expose Packer CLI
              packer = vmLib.mkPacker [ qemuPlugin ];
            };
        };
    };
}
