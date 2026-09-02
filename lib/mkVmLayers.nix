{
  pkgs,
  lib,
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
      # Use the user-provided function to link to the previous stage
      chained = if prevImage == null then { } else chain ref fun prevImage;

      # Resolve and merge the configs from the base, chain, and current stage
      config =
        ref: fun: lib.recursiveUpdate (lib.recursiveUpdate (base ref fun) chained) (stage.config ref fun);

      # Build the current stage using the provided suffix
      image = mkVmImage {
        inherit config useKVM plugins;

        name = "${name}-${stage.name}";
      };

      builder = mkVmBuilder {
        inherit config useKVM plugins;

        name = "${name}-${stage.name}";
      };

      prevDrvPath =
        if prevImage == null then null else builtins.unsafeDiscardStringContext prevImage.drvPath;
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
                BASE_IMAGE_DIR="$(nix-store --realise '${prevDrvPath}')"
                BASE_IMAGE="$BASE_IMAGE_DIR/${vmName}"

                exec ${builder}/bin/build-${name}-${stage.name}-vm -var "base_image=$BASE_IMAGE" "$@"
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
