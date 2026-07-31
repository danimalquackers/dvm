{
  pkgs,
  mkPacker,
  mkVmConfig,
}:

{
  name,
  config,
  plugins ? [ ],
}:

let
  customPacker = mkPacker plugins;
  configFile = mkVmConfig { inherit name config; };
in
pkgs.writeShellScriptBin "build-vm" ''
  # bash

  set -e

  # Run Packer using the wrapped binary and generated JSON config
  ${customPacker}/bin/packer build ${configFile}
''
