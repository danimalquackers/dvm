# DVM — Deterministic Virtual Machines

A Nix library for building and running reproducible VM images using [Packer](https://www.packer.io/) and [QEMU/KVM](https://www.qemu.org/).

## Features

- **Pure builds** — VM images are Nix derivations stored read-only in the Nix store
- **Full Packer language support** - Nix attribute sets are converted to Packer HCL2 JSON configuration files, with wrappers for easier function calling and references
- **Plugin support** - Supports any offline Packer plugins, not just QEMU/KVM
- **Nixpkgs overlay** - Add `mkVmConfig`, `mkVmImage`, and more to `pkgs` for easy invocation
- **Copy-on-write overlays** — Immutable base images with per-VM writable overlays via `mkVmRunner`
- **KVM acceleration** — Full hardware virtualization with automatic TCG fallback
- **Multi-OS support** — Built-in examples for NixOS (in progress), Ubuntu (in progress), and Windows
- **Headless & interactive** — Run impure VM builds with a GUI for troubleshooting

## Quick Start

```bash
# Build a Windows VM image
nix build .#windows

# Run a finished image
./result/bin/run-vm
```

## Requirements

- **Nix** (with flakes enabled)
- **KVM** — `/dev/kvm` must be accessible for hardware-accelerated builds
- **QEMU** — installed via Nixpkgs

## Usage

Begin by adding DVM as a flake input:

```nix
# flake.nix
{ inputs.dvm.url = "github:danimalquackers/dvm"; }
```

And importing the DVM Nixpkgs overlay:

```nix
{ pkgs, ... }: {
  nixpkgs.overlays = [ inputs.dvm.overlays.default ];
}
```

Then use the library functions directly from `pkgs`:

```nix
pkgs.mkVmImage {
  name = "my-vm";
  config = {
    packer.required_plugins.qemu = {
      version = ">= 1.1.0";
      source = "github.com/hashicorp/qemu";
    };

    source.qemu.myvm = {
      iso_url = "...";
      iso_checksum = "sha256:...";
      # ... Packer QEMU source config ...
    };

    build.sources = [ "source.qemu.myvm" ];
  };
}
```

Alternatively, instantiate the library directly with `pkgs`:

```nix
# flake.nix
{
  inputs.dvm.url = "github:danimalquackers/dvm";

  outputs = inputs@{ ... }:
    let
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
      vmLib = inputs.dvm.lib {
        inherit pkgs;
      };
    in {
      # use vmLib.mkVmImage, vmLib.mkVmRunner, etc.
    };
}
```

See [USAGE.md](USAGE.md) for the full API reference, default values, and Nix build environment details.

## Examples

The [`examples/`](./examples) directory contains ready-to-use configurations:

| Package | Description |
|---|---|
| `windows` | Windows 11 with UEFI + WinRM |
| `windows-debug` | Same as above with GUI console |

Build any example with `nix build .#<name>`. For `-debug` versions, use `nix run .#<name>` as these do not produce a derivation.

## Project Structure

```
├── flake.nix              # Flake entry point, devShell, packages
├── lib/
│   ├── default.nix        # Library exports
│   ├── fun.nix            # Packer language function wrappers
│   ├── mkPacker.nix       # Packer binary with plugin bundling
│   ├── mkPackerPlugin.nix # Packer plugin derivation helper
│   ├── mkVmBuilder.nix    # Interactive build script generator
│   ├── mkVmConfig.nix     # Nix.attrs → Packer JSON conversion
│   ├── mkVmImage.nix      # Nix derivation builder (store output)
│   ├── mkVmRunner.nix     # QEMU runner with COW overlays
│   └── ref.nix            # Packer variable reference helper
└── examples/
    └── windows/           # Windows 11 UEFI configuration
```

## AI Use Disclosure

Portions of this project were developed with the assistance of AI coding tools, including [Antigravity](https://antigravity.dev) and OpenCode/OpenChamber. All AI-generated code has been reviewed by a human.
