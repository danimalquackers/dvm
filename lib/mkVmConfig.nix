{
  pkgs,
}:

{ name, config }:

# Converts Nix attribute sets and lists into Packer-compatible HCL2 JSON
pkgs.writeText "${name}-packer.pkr.json" (builtins.toJSON config)
