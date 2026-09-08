{
  pkgs,
  lib,
  mkVmBuilder,
  mkVmImage,
}:

{
  name,
  base,
  chain,
  stages,
  useKVM ? true,
  plugins ? [ ],
}:

let
  initial = {
    prevImage = null;
    images = [ ];
    builders = [ ];
  };

  step =
    {
      prevImage,
      images,
      builders,
    }:
    stage:
    let
      ref = pkgs.callPackage ./ref.nix { };
      fun = pkgs.callPackage ./fun.nix { };

      # Derive the store paths for the previous image
      prevDrvPath =
        if prevImage == null then null else builtins.unsafeDiscardStringContext prevImage.drvPath;
      prevOutPath =
        if prevImage == null then null else builtins.unsafeDiscardStringContext prevImage.outPath;

      # Use the user-provided function to link to the previous stage
      chained = prev: if prev == null then { } else chain ref fun prev;

      # Helper for merging config layers
      mergeConfig =
        a: b:
        if builtins.isAttrs a && builtins.isAttrs b then
          lib.foldl' (
            merged: key:
            merged
            // {
              ${key} = if a ? ${key} && b ? ${key} then mergeConfig a.${key} b.${key} else b.${key} or a.${key};
            }
          ) { } (lib.unique (builtins.attrNames a ++ builtins.attrNames b))
        else if builtins.isList a && builtins.isList b then
          a ++ b
        else
          b;

      # Resolve and merge the configs from the base and current stage
      config = mergeConfig (base ref fun) (stage.config ref fun);

      # Build the current stage using the provided suffix
      image = mkVmImage {
        inherit useKVM plugins;

        name = "${name}-${stage.name}";
        config = ref: fun: mergeConfig config (chained prevImage);
      };

      # Create a builder for each layer that lazily builds prior stages
      builder = mkVmBuilder {
        inherit plugins;

        name = "${name}-${stage.name}";
        config = ref: fun: mergeConfig config (chained prevOutPath);
      };
    in
    {
      prevImage = image;
      builders = builders ++ [
        {
          name = stage.name;

          builder =
            if prevImage == null then
              builder
            else
              pkgs.writeShellScriptBin "build-${name}-${stage.name}-vm" ''
                # bash
                set -e

                echo "Building previous stage's image..." >&2
                nix-store --realise '${prevDrvPath}'

                exec ${builder}/bin/build-${name}-${stage.name}-vm "$@"
              '';

        }
      ];
      images = images ++ [
        {
          inherit image;

          name = stage.name;
        }
      ];
    };

  # Build an iterative chain of linked images
  result = lib.foldl' step initial stages;
in
{
  final = result.prevImage;

  # Images mapped by stage name
  images = lib.listToAttrs (map ({ name, image }: lib.nameValuePair name image) result.images);

  # Builders by stage name
  builders = lib.listToAttrs (
    map ({ name, builder }: lib.nameValuePair name builder) result.builders
  );
}
