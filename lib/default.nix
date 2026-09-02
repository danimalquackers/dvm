{
  pkgs,
  lib ? pkgs.lib,
  stdenv ? pkgs.stdenv,
}:

rec {
  # Core tools
  mkPackerPlugin = pkgs.callPackage ./mkPackerPlugin.nix { };
  mkPacker = pkgs.callPackage ./mkPacker.nix {
    inherit mkPackerPlugin;
  };

  mkVmConfig = pkgs.callPackage ./mkVmConfig.nix { };
  mkVmBuilder = pkgs.callPackage ./mkVmBuilder.nix {
    inherit mkPacker mkVmConfig;
  };
  mkVmImage = pkgs.callPackage ./mkVmImage.nix {
    inherit mkPacker mkVmConfig;
  };
  mkVmLayers = pkgs.callPackage ./mkVmLayers.nix {
    inherit mkVmBuilder mkVmImage;
  };
  mkVmRunner = pkgs.callPackage ./mkVmRunner.nix { };
  mkAutounattend = pkgs.callPackage ./mkAutounattend.nix { };

  # Packer syntax helpers
  ref = pkgs.callPackage ./ref.nix { };
  fun = pkgs.callPackage ./fun.nix { };
}
