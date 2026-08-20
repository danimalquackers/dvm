{
  pkgs,
  lib,
}:

{ name, config }:

let
  fun = pkgs.callPackage ./fun.nix { };

  # Call the config expression with the fun helper
  generatedConfig = config fun;

  # Inject OVMF file variables
  patchedConfig = generatedConfig // {
    variables = (generatedConfig.variables or { }) // {
      ovmf_code = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";
      ovmf_vars = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
    };

    # Conditionally inject the EFI firmware variables if EFI boot is enabled
    source = lib.mapAttrs (
      _: provider:
      lib.mapAttrs (
        _: source:
        source
        // lib.optionalAttrs (source.efi_boot) {
          efi_firmware_code = "\${var.ovmf_code}";
          efi_firmware_vars = "\${var.ovmf_vars}";
        }
      ) provider
    ) generatedConfig.source;
  };
in
# Converts Nix attribute sets and lists into Packer-compatible HCL2 JSON
pkgs.writeText "${name}-packer.pkr.json" (builtins.toJSON patchedConfig)
