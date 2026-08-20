{
  pkgs,
  vmLib,
  qemuPlugin,
}:

let
  windows = pkgs.callPackage ./windows { inherit vmLib qemuPlugin; };
in
windows
