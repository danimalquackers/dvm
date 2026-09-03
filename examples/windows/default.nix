{
  pkgs,
  vmLib,
}:

let
  config = ref: fun: {
    variables = {
      # System configuration
      computerName = "DVM-Windows";
      sku = "Windows 11 Pro";
      disk_size = "61440";
      memory = 4096;
      cpus = 2;

      # User configuration
      displayName = "Vagrant";
      username = "vagrant";
      password = "vagrant";

      # Build options
      restart_timeout = "5m";
      vm_name = "windows.qcow2";

      # Connection settings
      winrm_timeout = "1h";
    };

    locals = {
      # Build dependencies
      iso_url = pkgs.requireFile {
        name = "windows-11.iso";
        url = "https://www.microsoft.com/en-us/software-download/windows11";
        hash = "sha256-domEcGuQlHlBeyNoQ4kJRA8pZ/8FxqkZXtJmclTkZeM=";
      };
      iso_checksum = "sha256:768984706b909479417b2368438909440f2967ff05c6a9195ed2667254e465e3";

      virtio_win_iso = pkgs.fetchurl {
        url = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.285-1/virtio-win-0.1.285.iso";
        hash = "sha256-4UzyuUSSw+kl8AcLp/3+3rIEjJHuqcWlr7MCMqOXYzE=";
      };

      debloat_script =
        let
          debloat-src = pkgs.fetchFromGitHub {
            owner = "Raphire";
            repo = "Win11Debloat";
            rev = "2026.07.11";
            hash = "sha256-RuOySa9KYZj2eZiLU84/2l0/DPAjSyaz9HudWIYBc0Q=";
          };
          debloat =
            pkgs.runCommand "win11debloat-zip"
              {
                buildInputs = with pkgs; [ zip ];
              }
              ''
                mkdir -p $out

                cd ${debloat-src}

                # Zip the Win11Debloat tool
                zip -r $out/Win11Debloat.zip .
              '';
        in
        debloat;

      # Generate Autounattend answer file at Nix eval time (no HCL template needed)
      autounattend = vmLib.mkAutounattend {
        system.computerName = "DVM-Windows";
        users = [
          {
            username = "vagrant";
            password = "vagrant";
            displayName = "Vagrant";
          }
        ];
        image.sku = "Windows 11 Pro";
        virtio.version = "w11";
        commands = {
          firstLogon = [
            {
              description = "Set Execution Policy 64 Bit";
              commandLine = "cmd.exe /c powershell -Command \"Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force\"";
              synchronous = true;
            }
            {
              description = "Enable WinRM";
              commandLine = "cmd.exe /c C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -File E:\\enable-winrm.ps1";
              synchronous = true;
            }
          ];
        };
      };
    };

    packer.required_plugins.qemu = {
      version = ">= 1.1.0";
      source = "github.com/hashicorp/qemu";
    };

    source.qemu.windows = {
      boot_command = [
        "<enter>"
      ];
      boot_wait = "2s";

      # Hardware configuration
      cpus = ref.var "cpus";
      cpu_model = "host";
      memory = ref.var "memory";
      disk_size = ref.var "disk_size";
      disk_interface = "virtio";
      machine_type = "q35";
      accelerator = "kvm";

      # Windows image
      iso_checksum = ref.local "iso_checksum";
      iso_url = ref.local "iso_url";

      # Boot configuration
      efi_boot = true;

      vm_name = ref.var "vm_name";

      # Dynamically generated answer file and scripts
      cd_content = {
        "Autounattend.xml" = fun.file (ref.local "autounattend");
        "enable-winrm.ps1" = fun.file ./enable-winrm.ps1;
      };
      cd_files = [
        "${ref.local "debloat_script"}/Win11Debloat.zip"
      ];

      # Packer connection settings
      communicator = "winrm";
      winrm_username = ref.var "username";
      winrm_password = ref.var "password";
      winrm_timeout = ref.var "winrm_timeout";

      qemuargs = [
        # Virtio drivers disk
        [
          "--drive"
          "file=${ref.local "virtio_win_iso"},media=cdrom,index=2"
        ]

        # Disable Internet access for impure builds
        [
          "-netdev"
          "user,id=net0,restrict=y,hostfwd=tcp::{{ .SSHHostPort }}-:5985"
        ]
        [
          "-device"
          "virtio-net-pci,netdev=net0"
        ]
      ];
    };

    build = {
      sources = [ "source.qemu.windows" ];
      provisioner = [
        {
          # Install QEMU guest tools
          windows-shell = {
            inline = [
              "msiexec /i F:\\guest-agent\\qemu-ga-x86_64.msi /qn /norestart"
            ];
          };
        }

        {
          # Debloat the image as much as possible
          powershell = {
            inline = [
              "Expand-Archive -Path E:\\Win11Debloat.zip -DestinationPath C:\\Windows\\Temp\\Win11Debloat"
              "C:\\Windows\\Temp\\Win11Debloat\\Win11Debloat.ps1 -Silent -RemoveApps -DisableTelemetry"
              "Remove-Item -Path C:\\Windows\\Temp\\Win11Debloat -Recurse"
            ];
          };
        }

        {
          # Restart to allow changes to take effect
          windows-restart = {
            restart_timeout = "5m";
          };
        }
      ];
    };
  };
in
{
  windows = vmLib.mkVmImage {
    inherit config;

    name = "windows";
  };

  windows-debug = vmLib.mkVmBuilder {
    inherit config;

    name = "windows-debug";
  };
}
