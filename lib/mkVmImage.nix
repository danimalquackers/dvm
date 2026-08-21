{
  pkgs,
  lib,
  mkPacker,
  mkVmConfig,
}:

{
  name,
  config,
  plugins ? [ ],
  useKVM ? true,
}:

let
  customPacker = mkPacker plugins;
  configFile = mkVmConfig {
    inherit config;
  };
in
pkgs.stdenv.mkDerivation {
  pname = "${name}-image";
  version = "1.0.0";

  # Strictly require KVM from the Nix daemon unless overridden
  requiredSystemFeatures = lib.optionals useKVM [ "kvm" ];

  buildInputs = [ customPacker ];

  # Provide an empty environment to build in
  dontUnpack = true;

  # Fail early if KVM is unavailable
  preBuild = lib.optionalString useKVM ''
    # bash

    if [ ! -w /dev/kvm ]; then
      echo "ERROR: /dev/kvm is not accessible. KVM is required to build this image."
      exit 1
    fi
  '';

  buildPhase = ''
    # bash

    # Packer requires a writable HOME
    export HOME=$(mktemp -d)

    # Enable additional output for debugging
    export PACKER_LOG=1

    packer build ${configFile}
  '';

  installPhase = ''
    # bash

    # Copy the qcow2 image into the derivation output
    mkdir -p $out
    cp -r output/* $out/
  '';
}
