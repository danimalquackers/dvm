{
  pkgs,
  lib,
}:

plugins:

let
  # Combine the plugins into a single search path
  pluginDir = pkgs.symlinkJoin {
    name = "packer-plugin-directory";
    paths = plugins;
  };
in
pkgs.symlinkJoin {
  name = "packer";
  paths = with pkgs; [ packer ];
  buildInputs = with pkgs; [ makeWrapper ];

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
