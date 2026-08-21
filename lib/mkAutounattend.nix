{
  pkgs,
  lib,
}:

{
  username ? "vagrant",
  password ? "vagrant",
  displayName ? "Vagrant",
  computerName ? "DVM-Windows",
  sku ? "Windows 11 Pro",
  timeZone ? "Pacific Standard Time",
  locale ? "en-US",
  productKey ? null,
  enableVirtIO ? true,
  virtIODrive ? "F",
  windowsVersion ? "w10",
  bypassTPMCheck ? true,
  bypassSecureBootCheck ? true,
  enableAutoLogon ? true,
  disableHibernate ? true,
  oobeNetworkLocation ? "Home",
  diskConfig ? {
    efiSize = 100;
    msrSize = 16;
    label = "Windows";
  },
  firstLogonCommands ? [
    {
      description = "Set Execution Policy 64 Bit";
      commandLine = "cmd.exe /c powershell -Command \"Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force\"";
      requiresUserInput = true;
    }
  ],
  runSynchronousCommands ? [ ],
}:

let
  virtIORawVersion = if windowsVersion == "w11" then "w11" else "w10";

  virtIODrivers =
    if enableVirtIO then
      [
        {
          keyValue = "2";
          path = "${virtIODrive}:\\viostor\\${virtIORawVersion}\\amd64";
        }
        {
          keyValue = "3";
          path = "${virtIODrive}:\\NetKVM\\${virtIORawVersion}\\amd64";
        }
        {
          keyValue = "4";
          path = "${virtIODrive}:\\Balloon\\${virtIORawVersion}\\amd64";
        }
        {
          keyValue = "5";
          path = "${virtIODrive}:\\pvpanic\\${virtIORawVersion}\\amd64";
        }
        {
          keyValue = "6";
          path = "${virtIODrive}:\\qemupciserial\\${virtIORawVersion}\\amd64";
        }
        {
          keyValue = "7";
          path = "${virtIODrive}:\\qxldod\\${virtIORawVersion}\\amd64";
        }
        {
          keyValue = "8";
          path = "${virtIODrive}:\\vioinput\\${virtIORawVersion}\\amd64";
        }
        {
          keyValue = "9";
          path = "${virtIODrive}:\\viorng\\${virtIORawVersion}\\amd64";
        }
        {
          keyValue = "10";
          path = "${virtIODrive}:\\vioscsi\\${virtIORawVersion}\\amd64";
        }
        {
          keyValue = "11";
          path = "${virtIODrive}:\\vioserial\\${virtIORawVersion}\\amd64";
        }
      ]
    else
      [ ];

  driverPaths =
    if enableVirtIO then
      {
        DriverPaths = {
          PathAndCredentials = map (drv: {
            "+@wcm:action" = "add";
            "+@wcm:keyValue" = drv.keyValue;
            Path = drv.path;
          }) virtIODrivers;
        };
      }
    else
      { };

  runSynchronousSection =
    let
      builtinCmds = lib.filter (x: x != null) [
        (
          if bypassTPMCheck then
            {
              description = "Bypass TPM Check";
              path = "reg add HKLM\\SYSTEM\\Setup\\LabConfig /t REG_DWORD /v BypassTPMCheck /d 1 /f";
            }
          else
            null
        )
        (
          if bypassSecureBootCheck then
            {
              description = "Bypass Secure Boot Check";
              path = "reg add HKLM\\SYSTEM\\Setup\\LabConfig /t REG_DWORD /v BypassSecureBootCheck /d 1 /f";
            }
          else
            null
        )
      ];

      allCommands = builtinCmds ++ runSynchronousCommands;

      cmdsWithOrder = lib.imap1 (order: cmd: {
        "+@wcm:action" = "add";
        Description = cmd.description;
        Order = toString order;
        Path = cmd.path or cmd.commandLine or "";
      }) allCommands;
    in
    if lib.length cmdsWithOrder > 0 then
      {
        RunSynchronous = {
          RunSynchronousCommand = cmdsWithOrder;
        };
      }
    else
      { };

  firstLogonSection =
    let
      baseCommands = lib.filter (x: x != null) [
        {
          description = "Disable password expiration for ${username} user";
          commandLine = "cmd.exe /c wmic useraccount where \"name='${username}'\" set PasswordExpires=FALSE";
        }
        {
          description = "Enable AutoLogon Password";
          commandLine = "%SystemRoot%\\System32\\reg.exe ADD \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\" /v DefaultPassword /t REG_SZ /d \"${password}\" /f";
        }
        {
          description = "Enable AutoLogon";
          commandLine = "%SystemRoot%\\System32\\reg.exe ADD \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\" /v AutoAdminLogon /t REG_SZ /d 1 /f";
        }
      ];

      hibernateCommands =
        if disableHibernate then
          [
            {
              description = "Zero Hibernation File";
              commandLine = "%SystemRoot%\\System32\\reg.exe ADD HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power /v HibernateFileSizePercent /t REG_DWORD /d 0 /f";
            }
            {
              description = "Disable Hibernation Mode";
              commandLine = "%SystemRoot%\\System32\\reg.exe ADD HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power /v HibernateEnabled /t REG_DWORD /d 0 /f";
            }
          ]
        else
          [ ];

      allCmds = baseCommands ++ hibernateCommands ++ firstLogonCommands;

      cmdsWithOrder = lib.imap1 (
        order: cmd:
        {
          "+@wcm:action" = "add";
          CommandLine = cmd.commandLine;
          Description = cmd.description;
          Order = toString order;
        }
        // (if cmd.requiresUserInput or false then { RequiresUserInput = "true"; } else { })
      ) allCmds;
    in
    if lib.length cmdsWithOrder > 0 then
      {
        FirstLogonCommands = {
          SynchronousCommand = cmdsWithOrder;
        };
      }
    else
      { };

  autoLogon =
    if enableAutoLogon then
      {
        AutoLogon = {
          Password = {
            Value = password;
            PlainText = "true";
          };
          Username = username;
          Enabled = "true";
        };
      }
    else
      { };

  jsonStructure = {
    unattend = {
      "+@xmlns" = "urn:schemas-microsoft-com:unattend";
      servicing = "";
      settings = [
        {
          "+@pass" = "windowsPE";
          component = [
            (
              driverPaths
              // {
                "+@name" = "Microsoft-Windows-PnpCustomizationsWinPE";
                "+@publicKeyToken" = "31bf3856ad364e35";
                "+@language" = "neutral";
                "+@versionScope" = "nonSxS";
                "+@processorArchitecture" = "amd64";
                "+@xmlns:wcm" = "http://schemas.microsoft.com/WMIConfig/2002/State";
              }
            )
            (
              {
                "+@name" = "Microsoft-Windows-Setup";
                "+@publicKeyToken" = "31bf3856ad364e35";
                "+@language" = "neutral";
                "+@versionScope" = "nonSxS";
                "+@processorArchitecture" = "amd64";
                "+@xmlns:wcm" = "http://schemas.microsoft.com/WMIConfig/2002/State";
                "+@xmlns:xsi" = "http://www.w3.org/2001/XMLSchema-instance";

                DiskConfiguration = {
                  Disk = {
                    "+@wcm:action" = "add";
                    DiskID = "0";
                    WillWipeDisk = "true";
                    CreatePartitions = {
                      CreatePartition = [
                        {
                          "+@wcm:action" = "add";
                          Order = "1";
                          Type = "EFI";
                          Size = toString diskConfig.efiSize;
                        }
                        {
                          "+@wcm:action" = "add";
                          Order = "2";
                          Type = "MSR";
                          Size = toString diskConfig.msrSize;
                        }
                        {
                          "+@wcm:action" = "add";
                          Order = "3";
                          Type = "Primary";
                          Extend = "true";
                        }
                      ];
                    };
                    ModifyPartitions = {
                      ModifyPartition = [
                        {
                          "+@wcm:action" = "add";
                          Order = "1";
                          PartitionID = "1";
                          Format = "FAT32";
                          Label = "System";
                        }
                        {
                          "+@wcm:action" = "add";
                          Order = "2";
                          PartitionID = "2";
                        }
                        {
                          "+@wcm:action" = "add";
                          Order = "3";
                          PartitionID = "3";
                          Format = "NTFS";
                          Label = diskConfig.label;
                          Letter = "C";
                        }
                      ];
                    };
                  };
                  WillShowUI = "OnError";
                };

                UserData = {
                  AcceptEula = "true";
                  FullName = displayName;
                  Organization = displayName;
                  ProductKey = {
                    Key = if productKey != null then productKey else "";
                    WillShowUI = "Never";
                  };
                };

                ImageInstall = {
                  OSImage = {
                    InstallTo = {
                      DiskID = "0";
                      PartitionID = "3";
                    };
                    WillShowUI = "OnError";
                    InstallToAvailablePartition = "false";
                    InstallFrom = {
                      MetaData = {
                        "+@wcm:action" = "add";
                        Key = "/IMAGE/NAME";
                        Value = sku;
                      };
                    };
                  };
                };
              }
              // runSynchronousSection
            )
            {
              "+@name" = "Microsoft-Windows-International-Core-WinPE";
              "+@publicKeyToken" = "31bf3856ad364e35";
              "+@language" = "neutral";
              "+@versionScope" = "nonSxS";
              "+@processorArchitecture" = "amd64";
              "+@xmlns:wcm" = "http://schemas.microsoft.com/WMIConfig/2002/State";
              "+@xmlns:xsi" = "http://www.w3.org/2001/XMLSchema-instance";

              SetupUILanguage = {
                UILanguage = locale;
              };
              InputLocale = locale;
              SystemLocale = locale;
              UILanguage = locale;
              UILanguageFallback = locale;
              UserLocale = locale;
            }
          ];
        }
        {
          "+@pass" = "offlineServicing";
          component = [
            {
              "+@name" = "Microsoft-Windows-LUA-Settings";
              "+@publicKeyToken" = "31bf3856ad364e35";
              "+@language" = "neutral";
              "+@versionScope" = "nonSxS";
              "+@processorArchitecture" = "amd64";
              EnableLUA = "false";
            }
          ];
        }
        {
          "+@pass" = "oobeSystem";
          component = [
            {
              "+@name" = "Microsoft-Windows-International-Core";
              "+@publicKeyToken" = "31bf3856ad364e35";
              "+@language" = "neutral";
              "+@versionScope" = "nonSxS";
              "+@processorArchitecture" = "amd64";
              "+@xmlns:wcm" = "http://schemas.microsoft.com/WMIConfig/2002/State";
              "+@xmlns:xsi" = "http://www.w3.org/2001/XMLSchema-instance";
              InputLocale = locale;
              SystemLocale = locale;
              UILanguage = locale;
              UserLocale = locale;
            }
            (
              {
                "+@name" = "Microsoft-Windows-Shell-Setup";
                "+@publicKeyToken" = "31bf3856ad364e35";
                "+@language" = "neutral";
                "+@versionScope" = "nonSxS";
                "+@processorArchitecture" = "amd64";
                "+@xmlns:wcm" = "http://schemas.microsoft.com/WMIConfig/2002/State";
                "+@xmlns:xsi" = "http://www.w3.org/2001/XMLSchema-instance";

                UserAccounts = {
                  AdministratorPassword = {
                    Value = password;
                    PlainText = "true";
                  };
                  LocalAccounts = {
                    LocalAccount = {
                      "+@wcm:action" = "add";
                      Password = {
                        Value = password;
                        PlainText = "true";
                      };
                      Description = "Local User";
                      DisplayName = displayName;
                      Group = "administrators";
                      Name = username;
                    };
                  };
                };

                OOBE = {
                  HideEULAPage = "true";
                  HideWirelessSetupInOOBE = "true";
                  NetworkLocation = oobeNetworkLocation;
                  ProtectYourPC = "1";
                };

                ShowWindowsLive = "false";
              }
              // autoLogon
              // firstLogonSection
            )
          ];
        }
        {
          "+@pass" = "specialize";
          component = [
            {
              "+@name" = "Microsoft-Windows-Shell-Setup";
              "+@publicKeyToken" = "31bf3856ad364e35";
              "+@language" = "neutral";
              "+@versionScope" = "nonSxS";
              "+@processorArchitecture" = "amd64";

              OEMInformation = {
                HelpCustomized = "false";
              };
              ComputerName = computerName;
              TimeZone = timeZone;
              RegisteredOwner = "";
            }
            {
              "+@name" = "Microsoft-Windows-Security-SPP-UX";
              "+@publicKeyToken" = "31bf3856ad364e35";
              "+@language" = "neutral";
              "+@versionScope" = "nonSxS";
              "+@processorArchitecture" = "amd64";
              "+@xmlns:wcm" = "http://schemas.microsoft.com/WMIConfig/2002/State";
              "+@xmlns:xsi" = "http://www.w3.org/2001/XMLSchema-instance";
              SkipAutoActivation = "true";
            }
          ];
        }
      ];
    };
  };

  jsonFile = pkgs.writeText "Autounattend-raw.json" (builtins.toJSON jsonStructure);
in
pkgs.runCommand "Autounattend.xml"
  {
    buildInputs = with pkgs; [ yq-go ];
  }
  ''
    echo '<?xml version="1.0" encoding="utf-8"?>' > $out
    yq -p json -o xml '.' ${jsonFile} >> $out
  ''
