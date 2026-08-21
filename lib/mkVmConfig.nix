{
  pkgs,
  lib,
}:

{
  name,
  config,
}:

let
  ref = pkgs.callPackage ./ref.nix { };
  fun = pkgs.callPackage ./fun.nix { };

  # Call the config expression with the fun helper
  generatedConfig = config ref fun;

  # Inject OVMF file variables
  patchedConfig = generatedConfig // {
    variables = (generatedConfig.variables or { }) // {
      ovmf_code = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";
      ovmf_vars = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
    };

    source = lib.mapAttrs (
      _: provider:
      lib.mapAttrs (
        _: source:
        source
        // lib.optionalAttrs (source.efi_boot) {
          # Conditionally inject the EFI firmware variables
          efi_firmware_code = ref.var "ovmf_code";
          efi_firmware_vars = ref.var "ovmf_vars";
        }
        // {
          # Enforce headless mode unless otherwise specified
          headless = source.headless or true;
        }
      ) provider
    ) generatedConfig.source;
  };
in
# Converts Nix attribute sets and lists into Packer-compatible HCL2 JSON
pkgs.writeText "${name}-packer.pkr.json" (builtins.toJSON patchedConfig)
