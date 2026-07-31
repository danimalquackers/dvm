{
  pkgs,
  lib ? pkgs.lib,
  stdenv ? pkgs.stdenv,
}:

rec {
  mkPacker = pkgs.callPackage ./mkPacker.nix { };
  mkPackerPlugin = pkgs.callPackage ./mkPackerPlugin.nix { };

  mkVmConfig = pkgs.callPackage ./mkVmConfig.nix { };
  mkVmBuilder = pkgs.callPackage ./mkVmBuilder.nix {
    inherit mkPacker mkVmConfig;
  };
  mkVmImage = pkgs.callPackage ./mkVmImage.nix {
    inherit mkPacker mkVmConfig;
  };
  mkVmRunner = pkgs.callPackage ./mkVmRunner.nix { };
}
