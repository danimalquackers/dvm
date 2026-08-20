# DVM — Deterministic Virtual Machines

A Nix library for building and running reproducible VM images using [Packer](https://www.packer.io/) and [QEMU/KVM](https://www.qemu.org/).

## Features

- **Pure builds** — VM images are Nix derivations stored in the Nix store
- **Full Packer language support** - Nix attribute sets are converted to Packer HCL2 JSON configuration files for full Packer language support, with wrappers for easier function calling
- **Nixpkgs overlay** - Add `mkVmConfig`, `mkVmImage`, and more to `pkgs` for easy invocation
- **Copy-on-write overlays** — Immutable base images with per-run writable overlays via `mkVmRunner`
- **KVM acceleration** — Full hardware virtualization with automatic TCG fallback
- **Multi-OS support** — Built-in examples for NixOS (planned), Ubuntu (planned), and Windows
- **Headless & interactive** — Debug variants with GUI support for any VM configuration

## Quick Start

```bash
# Enter the development shell
nix develop

# Build a Windows VM image
nix build .#windows

# Build with a Packer CLI wrapper (includes QEMU plugin)
nix build .#packer

# Run a finished image
./result/bin/run-vm
```

## Library API

### `mkVmImage`

Build a VM image as a Nix derivation (runs inside `nix build`, pushes output to the store):

```nix
pkgs.mkVmImage {
  name = "my-vm";
  plugins = [ qemuPlugin ];
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

### `mkVmBuilder`

Generate a `build-vm` script for interactive Packer debug builds (outputs to current directory):

```nix
vmLib.mkVmBuilder {
  name = "my-vm-debug";
  plugins = [ qemuPlugin ];
  config = { /* ... */ };
}
```

### `mkVmRunner`

Create a `run-vm` script that launches a prebuilt VM image with a copy-on-write overlay:

```nix
vmLib.mkVmRunner {
  name = "my-vm";
  vmImage = ./path/to/image;
  memMb = 4096;
  cpus = 2;
}
```

Run with `./result/bin/run-vm`. Supported optional flags:
- `--disable-kvm` — fall back to TCG software emulation
- `--reset-overlay` — discard any preexisting writable overlay and start fresh

### `mkPackerPlugin`

Wrap a HashiCorp Packer plugin as a Nix derivation:

```nix
vmLib.mkPackerPlugin {
  name = "qemu";
  version = "1.1.6";
  hash = "sha256-...";
  binaries = [ pkgs.qemu_kvm ];
}
```

### `mkPacker`

Bundle Packer with plugins:

```nix
vmLib.mkPacker [ qemuPlugin ]
```

### `mkVmConfig`

Convert a Nix attribute set to a Packer JSON configuration file:

```nix
vmLib.mkVmConfig {
  name = "my-vm";
  config = ref: fun: { /* ... */ };
}
```

## Examples

The `examples/` directory contains ready-to-use configurations:

| Package | Description |
|---|---|
| `windows` | Windows 11 with UEFI + WinRM |
| `windows-debug` | Same as above with GUI console |

Build any example with `nix build .#<name>`.

## Using as a Library

Add DVM as a flake input, then instantiate the library with your `pkgs`:

```nix
# flake.nix
{
  inputs.dvm.url = "path:/to/dvm";

  outputs = inputs@{ ... }:
    let
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
      vmLib = inputs.dvm.lib {
        inherit pkgs;
        inherit (pkgs) lib stdenv;
      };
    in {
      # use vmLib.mkVmImage, vmLib.mkVmRunner, etc.
    };
}
```

Alternatively, add DVM as a Nixpkgs overlay:

```nix
# flake.nix
{ inputs.dvm.url = "path:/to/dvm"; }

...

{ pkgs, ... }: {
  nixpkgs.overlays = [ inputs.dvm.overlays.default ];
}
```

With the overlay, you can then use the library functions directly from `pkgs`:

```nix
pkgs.mkVmImage {
  name = "overlay-vm";
  plugins = [ qemuPlugin ];
  config = {
...
```

## Requirements

- **Nix** (with flakes enabled)
- **KVM** — `/dev/kvm` must be accessible for hardware-accelerated builds
- **QEMU** — installed via Nixpkgs (included in devShell)

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
