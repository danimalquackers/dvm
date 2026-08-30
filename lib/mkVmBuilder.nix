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

  configFile = mkVmConfig {
    inherit config;

    headless = false;
  };
in
pkgs.writeShellScriptBin "build-${name}-vm" ''
  # bash

  set -e

  # Enable additional output for debugging
  export PACKER_LOG=1

  # Run Packer using the wrapped binary and generated JSON config
  ${customPacker}/bin/packer build ${configFile}
''
