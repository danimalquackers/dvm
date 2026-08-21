{ pkgs, lib }:

{
  name,
  vmImage,
  memMb ? 4096,
  cpus ? 2,
  arch ? "x86_64",
  extraArgs ? [ ],
  useKVM ? true
}:

let
  baseImagePath = "${vmImage}/disk.qcow2";
  extraArgsStr = lib.escapeShellArgs extraArgs;
in
pkgs.writeShellScriptBin "run-vm" ''
  # bash

  set -euo pipefail

  # State directory resolution (defaults to $XDG_DATA_HOME/dvm/<vm-name>)
  STATE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/dvm/${name}"
  OVERLAY_DISK="$STATE_DIR/overlay.qcow2"

  DISABLE_KVM=${!useKVM}
  RESET_OVERLAY=false
  EXTRA_QEMU_ARGS=()

  # Parse runtime flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --disable-kvm)
        DISABLE_KVM=true
        shift
        ;;
      --reset-overlay)
        RESET_OVERLAY=true
        shift
        ;;
      --)
        shift
        EXTRA_QEMU_ARGS+=("$@")
        break
        ;;
      *)
        EXTRA_QEMU_ARGS+=("$1")
        shift
        ;;
    esac
  done

  # Store overlay disks in the user HOME
  mkdir -p "$STATE_DIR"

  # Wipe previous state if requested
  if [ "$RESET_OVERLAY" = true ] && [ -f "$OVERLAY_DISK" ]; then
    echo "Resetting overlay disk..."
    rm -f "$OVERLAY_DISK"
  fi

  # Create a QCOW2 overlay pointing to the immutable base image in store
  if [ ! -f "$OVERLAY_DISK" ]; then
    echo "Creating a copy-on-write overlay disk at $OVERLAY_DISK"
    ${pkgs.qemu-img}/bin/qemu-img create \
      -f qcow2 \
      -b "${baseImagePath}" \
      -F qcow2 \
      "$OVERLAY_DISK"
  fi

  # Acceleration flags check
  ACCEL_FLAGS="-enable-kvm -cpu host"
  if [ "$DISABLE_KVM" = true ]; then
    echo "Warning: KVM disabled via CLI flag. This likely will have a significant performance impact."
    ACCEL_FLAGS="-accel tcg"
  elif [ ! -w /dev/kvm ]; then
    echo "Warning: /dev/kvm is not writable. This likely will have a significant performance impact."
    ACCEL_FLAGS="-accel tcg"
  fi

  echo "Launching Virtual Machine ${name}..."
  exec ${lib.getExe' pkgs.qemu_kvm "qemu-system-" + arch} \
    $ACCEL_FLAGS \
    -m ${toString memMb} \
    -smp ${toString cpus} \
    -drive file="$OVERLAY_DISK",format=qcow2,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    ${extraArgsStr} \
    "''${EXTRA_QEMU_ARGS[@]}"
''
