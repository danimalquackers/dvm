{
  pkgs,
  lib,
  mkPackerPlugin,
}:

plugins:

let
  pluginsDefault =
    if plugins != [ ] then
      plugins
    else
      [
        (mkPackerPlugin {
          name = "qemu";
          version = "1.1.6";
          hash = "sha256-m5TExlmdPxKnp45SjheMggnUNo1D3KMr+uV1zC2f3Ts=";
          binaries = with pkgs; [
            qemu
            cdrtools
          ];
        })
      ];

  # Combine the plugins into a single search path
  pluginDir = pkgs.symlinkJoin {
    name = "packer-plugin-directory";
    paths = pluginsDefault;
  };
in
pkgs.symlinkJoin {
  name = "packer";
  paths = with pkgs; [ packer ];
  nativeBuildInputs = with pkgs; [ makeWrapper ];

  # Configures Packer with the provided plugins
  postBuild = ''
    wrapProgram $out/bin/packer \
      --set PACKER_PLUGIN_PATH "${pluginDir}" \
      --set CHECKPOINT_DISABLE "1"
  '';

  meta = with lib; {
    description = "Packer binary with bundled plugins";
    mainProgram = "packer";
    license = [ licenses.bsl11 ] ++ map (p: p.meta.license) plugins;
  };
}
