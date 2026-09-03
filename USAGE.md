# Usage

See the [`examples`](examples) directory for examples of how to use this module.

## Core Functions

### `mkVmConfig`

Converts a Nix attribute set to a Packer-compatible HCL2 JSON configuration (`.pkr.json`). Derivations can be consumed by `mkVmImage` and `mkVmBuilder`.

**Usage:**

```nix
vmConfig = pkgs.mkVmConfig {
  config = {
    variables = [ ... ];
    sources = { ... };
    builders = [ ... ];
    provisioners = { ... };
    post-processors = [ { ... } ];
  };

  # optional
  headless = true;
};
```

**Required Fields:**

- `config` - The Packer configuration written in Nix but matching the Packer HCL2 schema. `config` is not type safe and will accept any Nix input without warnings or validation. However, Packer will throw errors for invalid syntax.

**Defaults:**

- `headless` (QEMU only) — Packer runs without opening a QEMU virtual machine viewer, defaults to `true`. Set to `false` for interactive build output. This is set to false automatically when using `mkVmBuilder`.
- `config.sources.qemu.<source>.efi_firmware_code` and `config.sources.qemu.<source>.efi_firmware_vars` (per source - QEMU only) — If `efi_boot` is `true`, these variables are auto-injected to allow proper resolution on NixOS systems. Set to override.

---

### `mkVmImage`

Builds a VM image as a Nix derivation. This is the primary function for producing VM image builds.

**Usage:**

```nix
vmImage = pkgs.mkVmImage {
  name = "my-image";
  config = { ... };

  # optional:
  plugins = [ qemuPlugin ];
  useKVM = true;
};
```

**Required fields:**

- `name` — Image name, used for output artifact naming and derivation name
- `config` — A Packer configuration attribute set (passed to `mkVmConfig`)

**Optional fields:**

- `plugins` - Packer plugins needed for the build, the Packer QEMU plugin is used if unset
- `useKVM` - Use KVM acceleration while building the image, defaults to `true` (recommended)

**Notes:**

- `PACKER_LOG = 1` is set for build debugging
- HOME is forced to a fresh `mktemp -d` directory because `/nix` HOME lacks writable permissions required by Packer
- Setting `useKVM = true` adds `kvm` to the required Nix features and checks that `/dev/kvm` is present, but will not override any KVM flags within the `config` block.
- Internet access is not available to Packer or the VM while building in the Nix sandbox.

---

### `mkVmBuilder`

Generates a standalone `build-vm` script for interactive, non-pure debugging of Packer builds outside the Nix sandbox. This is useful when combined with the `breakpoint` provisioner to troubleshoot issues.

**Usage:**

```nix
vmBuilder = pkgs.mkVmBuilder {
  config = { ... };

  # optional
  plugins = [ qemuPlugin ];
};
```

**Required fields:**

- `name` - VM name, used for build script naming
- `config` - A Packer configuration attribute set (passed to `mkVmConfig`)

**Optional fields:**

- `plugins` - Packer plugins needed for the build, the Packer QEMU plugin is used if unset

**Notes:**

- The builder sets `headless = false` on `mkVmConfig` by default.

---

### `mkVmRunner`

Generates a `run-vm` script to run a VM using an image produced by `mkVmImage`. Calls QEMU with an overlay disk to allow writes by the guest OS. This helper only supports QEMU virtual machines.

**Usage:**

```nix
vmRunner = pkgs.mkVmRunner {
  name = "my-vm";
  image = /path/to/image.qcow2;

  # optional:
  cpus = 2;
  mem = 4096;
  arch = "x86_64";
  machineType = "i440fx";
  display = "vga";
  kvm = true;
  efi = false;
  portForwards = [ ];
  extraArgs = [ ... ];
};
```

**Required:**

- `name` - The name of the VM, used to discriminate VM instances, such as when two VMs share the same base image.
- `image` - The path to the base VM image (in qcow2 format) to run.

**Optional:**

- `cpus` - The number of virtual CPUs to allocate to the VM, defaults to 2
- `mem` - The amount of memory to allocate to the VM in MB, defaults to 4096
- `arch` - The architecture of the VM, defaults to the current system architecture
- `machineType` - The machine type to use for the VM ("i440fx" or "q35"), defaults to "i440fx"
- `display` - The display to use for the VM ("vga", "spice", or "none"), defaults to "vga"
- `kvm` - Whether to use KVM for acceleration, defaults to `true`
- `efi` - Whether to use EFI for booting, defaults to `false`
- `portForwards` - A list of port forwards to apply to the host, accepts attrsets in the format `{ host = <port>; guest = <port>; }`
- `extraArgs` - A list of extra arguments to pass to QEMU, including overrides for any defaults set by `mkVmRunner`

**Runtime Flags:**

The `run-vm` script produced by this derivation provides the following runtime flags:

- `--disable-kvm` — Force TCG software emulation (fallback when `/dev/kvm` unavailable)
- `--reset-overlay` — Delete the COW overlay disk, preserving the base image unchanged
- `--` followed by any additional flags — Pass additional arguments directly to QEMU

**Notes:**

- An overlay `.qcow2` image is written to `$XDG_DATA_HOME/dvm/<name>/`. The read-only base image remains unchanged, all VM writes go to the overlay.

---

### `mkVmLayers`

Build a chain of multi-stage VM images, where each stage extends the previous one. Useful for multi-step setups (e.g., base OS → drivers → applications). This also takes advantage of Nix build caching, similar to Dockerfile layers.

**Usage:**

```nix
pkgs.mkVmLayers {
  name = "my-vm";
  base = ref: fun: {
    /* shared base config */
  };
  chain = ref: fun: prevImage: {
    /* config snippet dynamically referencing previous stage */
  };
  stages = [
    { name = "base-os"; config = ref: fun: { /* stage 1 */; }; }
    { name = "drivers"; config = ref: fun: { /* stage 2 */; }; }
    { name = "apps"; config = ref: fun: { /* stage 3 */; }; }
  ];

  # optional
  useKVM = true;
  plugins = [ ];
}
```

**Required:**

- `name` — Prefix for derived image names (`<name>-<stage>`)
- `base` — Base Packer config function (`ref: fun: { ... }`) merged into every stage
- `chain` — Function (`ref: fun: prevImage: { ... }`) that produces config referencing the previous stage's image. Empty `{ }` for the first stage.
- `stages` — List of `{ name, config }` objects, each with a stage name and a Packer config function, merged with the base and chain configs

**Optional:**

- `useKVM` - Use KVM acceleration while building the image, defaults to `true` (recommended)
- `plugins` - Packer plugins needed for the build, the Packer QEMU plugin is used if unset


**Notes:**

- Each stage's final config is: `base` ← `chained` ← `stage.config` (rightmost wins on conflicts).
- The final images is available as `.final`. Each stage also produces images in `.images.<stage>`, and runtime builders are available as `.builders.<stage>`.

**Returned attributes:**

| Attribute | Description |
|---|---|
| `final` | The last stage's `mkVmImage` derivation |
| `images` | Attribute set mapping stage name → image derivation |
| `builders` | Attribute set mapping stage name → builder script derivation |

---

## Helper Modules

### `mkPacker`

Bundles and initializes the `packer` binary with offline plugins.

**Usage:**

```nix
myPacker = pkgs.mkPacker [
  (pkgs.mkPackerPlugin { name = "qemu"; version = "1.1.6"; hash = "..."; binaries = ...; })
];
```

**Required:**

- A list of `mkPackerPlugin` derivations. If the list is empty, defaults to a QEMU plugin with `qemu` and `cdrtools` binaries.

---

### `mkPackerPlugin`

Fetches a Packer plugin from HashiCorp's releases and pre-computes the SHA256 checksum to bypass `packer init`.

**Usage:**

```nix
plugin = pkgs.mkPackerPlugin {
  name = "qemu";
  version = "1.1.6";
  hash = "sha256-m5TExlmdPxKnp45SjheMggnUNo1D3KMr+uV1zC2f3Ts=";
  binaries = with pkgs; [ qemu cdrtools ];

  # optional
  publisher = "hashicorp";
};
```

**Required:**

- `name` - Plugin name in the Hashicorp registry (e.g., `"qemu"`, `"amazon"`)
- `version` - Plugin version string in the hashicorp registry
- `hash` - SRI hash of the tarball, downloaded from `https://releases.hashicorp.com`
- `binaries` - List of Nixpkgs packages required by the plugin whose binaries should be prefixed to `PATH`

**Optional:**

- `publisher` - Plugin publisher in the Hashicorp registry (e.g., `"hashicorp"`, `"dheerajd"`)

**Notes:**

- The `_SHA256SUM` file is pre-computed and placed alongside the extracted binary, so Packer skips its online checksum verification on startup.
- Binaries from the `binaries` list are wrapped into the plugin by prefixing them to `PATH`.

---

### `mkAutounattend`

Generates an `Autounattend.xml` file for unattended Windows installations with sensible defaults and maximum flexibility.

**Usage:**

```nix
autounattend = pkgs.mkAutounattend {
  system.computerName = "DVM-Windows";
  image.sku = "Windows 11 Pro";

  # User Configuration
  users = [
    {
      username = "vagrant";
      password = "vagrant";
      displayName = "Vagrant";
      group = "administrators";
    }
  ];

  # VirtIO Drivers
  virtio.version = "w11";

  # Security & UAC
  enableLUA = true; # Set false to disable UAC prompts, or null to omit LUA settings

  # Partitioning Options
  diskConfig = {
    efiSize = 100;
    msrSize = 16;
    label = "Windows";
  };

  # Commands Per Phase
  commands = {
    windowsPE = [ ];
    specialize = [ ];
    oobeSystem = [ ];
    firstLogon = [
      {
        description = "Enable WinRM";
        commandLine = "cmd.exe /c C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -File E:\\enable-winrm.ps1";
      }
    ];
  };
};
```

**Optional:**

- `system` - System identity and localization options, defaults to `{ }`.
  - `computerName` - Host computer name (defaults to `"DVM-Windows"`).
  - `timeZone` - Time zone name (defaults to `"Pacific Standard Time"`).
  - `locale` - System locale (defaults to `"en-US"`).
  - `registeredOwner` - Registered owner string (defaults to `""`).
  - `registeredOrganization` - Registered organization string (defaults to `""`).
- `image` - OS image & SKU selection options, defaults to `{ }`.
  - `sku` - Windows edition name matching ISO metadata (defaults to `"Windows 11 Pro"`).
  - `index` - Optional OS image index in WIM/ISO (defaults to `null`).
  - `metaData` - Explicit custom image metadata key/value set (defaults to `null`).
- `users` - List of user account attrsets, defaults to a single `vagrant` user account.
  - `username` (or `name`) - Account username (defaults to `"vagrant"`).
  - `password` - Account password (defaults to `"vagrant"`).
  - `displayName` - Account display name (defaults to `username`).
  - `group` - Group membership (defaults to `"administrators"`).
  - `description` - User account description (defaults to `"Local User"`).
- `administratorPassword` - Explicit Administrator password, defaults to the primary user's password.
- `enableLUA` - User Account Control (UAC/LUA) setting (`true` enables UAC, `false` disables UAC, `null` omits component), defaults to `true`.
- `oobe` - Out-Of-Box Experience & AutoLogon configuration, defaults to `{ }`.
  - `autoLogon` - AutoLogon options (`{ enable ? true, user ? null, password ? null, count ? null }`).
  - `networkLocation` - Network location setting (defaults to `"Home"`).
  - `protectYourPC` - Protect your PC setting (defaults to `"3"`).
  - `hideEULA` - Hide EULA page during OOBE (defaults to `true`).
  - `hideWirelessSetup` - Hide wireless setup in OOBE (defaults to `true`).
- `virtio` - VirtIO driver configuration, defaults to `{ }`.
  - `enable` - Auto-inject VirtIO storage, network, and guest agent driver paths (defaults to `true`).
  - `drive` - Drive letter of the mounted VirtIO driver ISO (defaults to `"F"`).
  - `version` - Target VirtIO driver OS version (`"w10"` or `"w11"`, defaults to `"w10"`).
  - `drivers` - Custom list of VirtIO driver paths (defaults to standard QEMU driver set).
- `diskConfig` - Disk partitioning options, defaults to `{ }`.
  - `diskID` - ID of disk to partition (defaults to `"0"`).
  - `willWipeDisk` - Whether to wipe existing disk contents (defaults to `true`).
  - `efiSize` - EFI partition size in MB (defaults to `100`).
  - `msrSize` - MSR partition size in MB (defaults to `16`).
  - `label` - Windows primary partition label (defaults to `"Windows"`).
  - `letter` - Windows primary partition drive letter (defaults to `"C"`).
  - `createPartitions` - Custom list of create partition specifications (defaults to `null`).
  - `modifyPartitions` - Custom list of modify partition specifications (defaults to `null`).
- `tweaks` - Setup tweaks & workarounds, defaults to `{ }`.
  - `bypassTPM` - Bypass Windows 11 TPM requirements during setup (defaults to `true`).
  - `bypassSecureBoot` - Bypass Windows 11 Secure Boot requirements during setup (defaults to `true`).
  - `disableHibernate` - Disable Windows hibernation and zero hibernation file size (defaults to `false`).
- `commands` - Phase-based command lists, defaults to `{ }`.
  - `windowsPE` - Commands executed during the `windowsPE` pass.
  - `specialize` - Commands executed during the `specialize` pass.
  - `oobeSystem` - Commands executed during the `oobeSystem` pass.
  - `firstLogon` - Commands executed upon first user logon.
  - *Command items can be strings (e.g. `"cmd.exe /c ..."`) or attribute sets:*
    - `commandLine` / `path` - Command string to execute.
    - `description` - Optional command description.
    - `synchronous` - Whether the command runs synchronously (defaults to `true`).
    - `requiresUserInput` - Whether the command requires user input (defaults to `false`, `firstLogon` commands only).

---

### `ref` — Variable References

Produce Packer-style `${var}` references with type safety.

| Function | Input | Output |
|---|---|---|
| `ref.var` | `ref.var name` | `"${var.name}"` |
| `ref.local` | `ref.local name` | `"${local.name}"` |
| `ref.env` | `ref.env name` | `${env.name}$` |
| `ref.path` | `ref.path "cwd"` | `${path.cwd}` (only `cwd` and `root` are allowed) |

---

### `fun` — Packer Functions

Wrappers around packer functions (for use in provisioner scripts and similar contexts). See [fun.nix](./lib/fun.nix) for the full list of available functions.

---
