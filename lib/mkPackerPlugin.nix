{
  pkgs,
  lib,
  stdenv,
}:

{
  name,
  version,
  hash,
  binaries ? [ ],
  publisher ? "hashicorp",
}:

let
  os = if stdenv.isDarwin then "darwin" else "linux";
  arch = if stdenv.isAarch64 then "arm64" else "amd64";
in
stdenv.mkDerivation {
  pname = "packer-plugin-${name}";
  inherit version;

  src = pkgs.fetchzip {
    inherit hash;

    url = "https://releases.hashicorp.com/packer-plugin-${name}/${version}/packer-plugin-${name}_${version}_${os}_${arch}.zip";
    stripRoot = false;
  };

  nativeBuildInputs = with pkgs; [ makeWrapper ];

  installPhase =
    let
      binPath = lib.makeBinPath binaries;
    in
    ''
      # bash

      # Copy plugin to the derivation output
      pluginDir=$out/github.com/${publisher}/${name}
      mkdir -p "$pluginDir"

      cp $src/packer-plugin-${name}_v${version}_* "$pluginDir/"
      chmod +x "$pluginDir"/packer-plugin-${name}_v${version}_*

      for binary in "$pluginDir"/packer-plugin-${name}_v${version}_*; do
        # Expose supporting binaries (e.g. qemu) via PATH
        wrapProgram "$binary" \
          --prefix PATH : ${binPath}

        # Precompute the SHA256SUM of the plugin (avoids `packer init`)
        sha256sum "$binary" | awk '{print $1}' > "''${binary}_SHA256SUM"
      done
    '';
}
