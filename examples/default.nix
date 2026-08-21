{
  pkgs,
  vmLib,
}:

let
  windows = pkgs.callPackage ./windows { inherit vmLib; };
in
windows
