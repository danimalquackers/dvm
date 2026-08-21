{
  pkgs,
  lib,
}:

{
  config,
  headless ? true,
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
      pname: provider:
      lib.mapAttrs (
        _: source:
        source
        // lib.optionalAttrs (pname == "qemu") (
          {
            # Override headless mode if unset
            headless = source.headless or headless;
          }
          // lib.optionalAttrs (source.efi_boot) {
            # Conditionally inject the EFI firmware variables
            efi_firmware_code = source.efi_firmware_code or ref.var "ovmf_code";
            efi_firmware_vars = source.efi_firmware_vars or ref.var "ovmf_vars";
          }
        )
      ) provider
    ) generatedConfig.source;
  };
in
# Converts Nix attribute sets and lists into Packer-compatible HCL2 JSON
pkgs.writeText "packer.pkr.json" (builtins.toJSON patchedConfig)
