{ pkgs, lib }:

{
  name,
  image,
  cpus ? 2,
  mem ? 4096,
  arch ? pkgs.stdenv.hostPlatform.parsed.cpu.name,
  machineType ? "i440fx",
  display ? "vga",
  kvm ? true,
  efi ? false,
  portForwards ? [ ],
  extraArgs ? [ ],
}:

let
  # Accept arbitrary QEMU arguments
  extraArgsStr = lib.escapeShellArgs (lib.flatten extraArgs);

  # Generate a list of port forwards (if enabled)
  hostfwdFlags = lib.concatMapStringsSep "," (
    fwd: "hostfwd=tcp::${toString fwd.host}-:${toString fwd.guest}"
  ) portForwards;
in
pkgs.writeShellScriptBin "run-vm" ''
  # bash

  set -euo pipefail

  # State directory resolution (defaults to $XDG_DATA_HOME/dvm/<vm-name>)
  STATE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/dvm/${name}"
  OVERLAY_DISK="$STATE_DIR/overlay.qcow2"

  MACHINE_TYPE="${machineType}"
  VIDEO_MODE="${display}"
  DISABLE_KVM=${lib.boolToString (!kvm)}
  ENABLE_EFI=${lib.boolToString efi}
  PORT_FORWARDS="${hostfwdFlags}"
  EXTRA_QEMU_ARGS=(${lib.escapeShellArgs extraArgs})
  RESET_OVERLAY=false

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
    ${lib.getExe pkgs.qemu-img} create \
      -f qcow2 \
      -b "${image}" \
      -F qcow2 \
      "$OVERLAY_DISK"
  fi

  # Acceleration flags check
  ACCEL_FLAGS="-enable-kvm -cpu host"
  if [ "$DISABLE_KVM" = true ] || [ ! -w /dev/kvm ]; then
    echo "Warning: KVM is disabled or unavailable. This will have a significant performance impacts."
    ACCEL_FLAGS="-accel tcg"
  fi

  # Correctly link OVMF for UEFI boot
  BOOT_FLAGS=""
  if [ "$ENABLE_EFI" = true ]; then
    MACHINE_TYPE="q35"
    BOOT_FLAGS="-bios ${pkgs.OVMF_fd}/FV/OVMF.fd"
  fi

  # Support SPICE and headless VMs
  VIDEO_FLAGS="-vga std"
  if [ "$VIDEO_MODE" = "qxl" ]; then
    VIDEO_FLAGS="-vga qxl -spice port=5900,disable-ticketing"
  elif [ "$VIDEO_MODE" = "none" ]; then
    VIDEO_FLAGS="-vga std -display none"
  fi

  # Port-forwarding flags are generated statically by Nix at eval time.
  NETDEV_FLAGS="-netdev user,id=net0"
  if [ "$PORT_FORWARDS" != "" ]; then
    NETDEV_FLAGS+=",$PORT_FORWARDS"
  fi
  NETDEV_FLAGS+=" -device virtio-net-pci,netdev=net0"

  echo "Launching Virtual Machine ${name}..."
  exec ${lib.getExe' pkgs.qemu_kvm "qemu-system-" + arch} \
    -m ${toString mem} \
    -smp ${toString cpus} \
    -M ''${MACHINE_TYPE} \
    -drive file="$OVERLAY_DISK",format=qcow2,if=virtio \
    ''${ACCEL_FLAGS} \
    ''${BOOT_FLAGS} \
    ''${VIDEO_FLAGS} \
    ''${NETDEV_FLAGS} \
    "''${EXTRA_QEMU_ARGS[@]}"
''
