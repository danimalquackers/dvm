{
  pkgs,
  lib,
}:

{
  # System identity & localization
  # Structure: { computerName ? "DVM-Windows", timeZone ? "Pacific Standard Time", locale ? "en-US", registeredOwner ? "", registeredOrganization ? "" }
  system ? { },

  # User accounts list parameter
  # Each element: { username (or name), password, displayName ?, group ?, description ? }
  users ? [
    {
      username = "vagrant";
      password = "vagrant";
      displayName = "Vagrant";
      group = "administrators";
      description = "Local User";
    }
  ],
  administratorPassword ? null,

  # OS Image & SKU Selection
  # Structure: { sku ? "Windows 11 Pro", index ? null, metaData ? null }
  image ? { },

  # Product & Licensing
  productKey ? null,
  acceptEula ? true,

  # VirtIO Drivers Configuration
  # Structure: { enable ? true, drive ? "F", version ? "w10", drivers ? null }
  virtio ? { },

  # UAC / LUA Settings (defaults to true; set false to disable UAC, or null to omit element)
  enableLUA ? true,

  # Out-Of-Box-Experience & AutoLogon Configuration
  # Structure: { autoLogon ? { enable ? true, user ? null, password ? null, count ? null }, protectYourPC ? "3", networkLocation ? "Home", hideEULA ? true, hideWirelessSetup ? true }
  oobe ? { },

  # Disk Partitioning Options
  # Structure: { diskID ? "0", willWipeDisk ? true, efiSize ? 100, msrSize ? 16, label ? "Windows", letter ? "C", installToDisk ? "0", installToPartition ? "3", createPartitions ? null, modifyPartitions ? null }
  diskConfig ? { },

  # Setup Tweaks & Workarounds
  # Structure: { bypassTPM ? true, bypassSecureBoot ? true, disableHibernate ? false }
  tweaks ? { },

  # Consolidated commands attribute set
  # Structure: { windowsPE = [ ]; specialize = [ ]; oobeSystem = [ ]; firstLogon = [ ]; }
  # Command elements can be strings or attrsets: { commandLine/path, description ?, synchronous ? true, requiresUserInput ? false }
  commands ? { },
}:

let
  # System settings
  computerName = system.computerName or "DVM-Windows";
  registeredOwner = system.registeredOwner or "";
  registeredOrganization = system.registeredOrganization or "";
  timeZone = system.timeZone or "Pacific Standard Time";
  locale = system.locale or "en-US";

  # User accounts normalization
  normalizedUsers = map (
    u:
    let
      uname = u.username or u.name or "vagrant";
    in
    {
      username = uname;
      password = u.password or "";
      displayName = u.displayName or uname;
      group = u.group or "administrators";
      description = u.description or "Local User";
    }
  ) users;

  primaryUser = if lib.length normalizedUsers > 0 then builtins.head normalizedUsers else null;

  adminPass =
    if administratorPassword != null then
      administratorPassword
    else if primaryUser != null then
      primaryUser.password
    else
      null;

  # OS Image settings
  sku = image.sku or image.name or "Windows 11 Pro";
  imageIndex = image.index or null;
  imageMetaData = image.metaData or null;

  # VirtIO drivers setup (using lowercase virtio casing)
  virtioEnable = virtio.enable or true;
  virtioDrive = virtio.drive or "F";
  virtioVersion = virtio.version or "w10";
  virtioDriversSpec = virtio.drivers or null;

  virtioRawVersion = if virtioVersion == "w11" then "w11" else "w10";

  defaultVirtioDrivers = [
    {
      keyValue = "2";
      path = "${virtioDrive}:\\viostor\\${virtioRawVersion}\\amd64";
    }
    {
      keyValue = "3";
      path = "${virtioDrive}:\\NetKVM\\${virtioRawVersion}\\amd64";
    }
    {
      keyValue = "4";
      path = "${virtioDrive}:\\Balloon\\${virtioRawVersion}\\amd64";
    }
    {
      keyValue = "5";
      path = "${virtioDrive}:\\pvpanic\\${virtioRawVersion}\\amd64";
    }
    {
      keyValue = "6";
      path = "${virtioDrive}:\\qemupciserial\\${virtioRawVersion}\\amd64";
    }
    {
      keyValue = "7";
      path = "${virtioDrive}:\\qxldod\\${virtioRawVersion}\\amd64";
    }
    {
      keyValue = "8";
      path = "${virtioDrive}:\\vioinput\\${virtioRawVersion}\\amd64";
    }
    {
      keyValue = "9";
      path = "${virtioDrive}:\\viorng\\${virtioRawVersion}\\amd64";
    }
    {
      keyValue = "10";
      path = "${virtioDrive}:\\vioscsi\\${virtioRawVersion}\\amd64";
    }
    {
      keyValue = "11";
      path = "${virtioDrive}:\\vioserial\\${virtioRawVersion}\\amd64";
    }
  ];

  activeVirtioDrivers = if virtioDriversSpec != null then virtioDriversSpec else defaultVirtioDrivers;

  driverPathsComponent =
    if virtioEnable then
      {
        DriverPaths = {
          PathAndCredentials = map (drv: {
            "+@wcm:action" = "add";
            "+@wcm:keyValue" = drv.keyValue;
            Path = drv.path;
          }) activeVirtioDrivers;
        };
      }
    else
      { };

  # OOBE & AutoLogon settings
  autoLogonConfig = oobe.autoLogon or { };
  enableAutoLogon = autoLogonConfig.enable or true;
  autoLogonUser =
    if autoLogonConfig ? user then
      autoLogonConfig.user
    else if primaryUser != null then
      primaryUser.username
    else
      null;
  autoLogonPassword =
    if autoLogonConfig ? password then
      autoLogonConfig.password
    else if primaryUser != null then
      primaryUser.password
    else
      null;
  autoLogonCount = autoLogonConfig.count or null;

  protectYourPC = oobe.protectYourPC or "3";
  oobeNetworkLocation = oobe.networkLocation or "Home";
  hideEULAPage = oobe.hideEULA or true;
  hideWirelessSetupInOOBE = oobe.hideWirelessSetup or true;

  # Setup Tweaks & Workarounds
  bypassTPM = tweaks.bypassTPM or true;
  bypassSecureBoot = tweaks.bypassSecureBoot or true;
  disableHibernate = tweaks.disableHibernate or false;

  # Helper functions for normalizing command lists
  normalizeCmd =
    cmd:
    if builtins.isString cmd then
      {
        commandLine = cmd;
        path = cmd;
        description = "";
        requiresUserInput = false;
        synchronous = true;
      }
    else
      {
        commandLine = cmd.commandLine or cmd.path or "";
        path = cmd.path or cmd.commandLine or "";
        description = cmd.description or "";
        requiresUserInput = cmd.requiresUserInput or false;
        synchronous = cmd.synchronous or true;
      };

  # Command list processing per phase
  rawWindowsPECommands =
    (lib.filter (x: x != null) [
      (
        if bypassTPM then
          {
            description = "Bypass TPM Check";
            path = "reg add HKLM\\SYSTEM\\Setup\\LabConfig /t REG_DWORD /v BypassTPMCheck /d 1 /f";
            synchronous = true;
          }
        else
          null
      )
      (
        if bypassSecureBoot then
          {
            description = "Bypass Secure Boot Check";
            path = "reg add HKLM\\SYSTEM\\Setup\\LabConfig /t REG_DWORD /v BypassSecureBootCheck /d 1 /f";
            synchronous = true;
          }
        else
          null
      )
    ])
    ++ (commands.windowsPE or [ ]);

  rawSpecializeCommands = commands.specialize or [ ];

  rawOobeSystemCommands = commands.oobeSystem or [ ];

  rawFirstLogonCommands =
    (
      if disableHibernate then
        [
          {
            description = "Zero Hibernation File";
            commandLine = "%SystemRoot%\\System32\\reg.exe ADD HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power /v HibernateFileSizePercent /t REG_DWORD /d 0 /f";
            synchronous = true;
          }
          {
            description = "Disable Hibernation Mode";
            commandLine = "%SystemRoot%\\System32\\reg.exe ADD HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power /v HibernateEnabled /t REG_DWORD /d 0 /f";
            synchronous = true;
          }
        ]
      else
        [ ]
    )
    ++ (commands.firstLogon or [ ]);

  # Filter synchronous commands for XML output
  windowsPESyncCommands = lib.filter (c: c.synchronous) (map normalizeCmd rawWindowsPECommands);
  specializeSyncCommands = lib.filter (c: c.synchronous) (map normalizeCmd rawSpecializeCommands);
  oobeSystemSyncCommands = lib.filter (c: c.synchronous) (map normalizeCmd rawOobeSystemCommands);
  firstLogonSyncCommands = lib.filter (c: c.synchronous) (map normalizeCmd rawFirstLogonCommands);

  formatRunSynchronous =
    cmdList:
    let
      ordered = lib.imap1 (order: cmd: {
        "+@wcm:action" = "add";
        Description = cmd.description;
        Order = toString order;
        Path = cmd.path;
      }) cmdList;
    in
    if lib.length ordered > 0 then
      {
        RunSynchronous = {
          RunSynchronousCommand = ordered;
        };
      }
    else
      { };

  formatFirstLogon =
    cmdList:
    let
      ordered = lib.imap1 (
        order: cmd:
        {
          "+@wcm:action" = "add";
          CommandLine = cmd.commandLine;
          Description = cmd.description;
          Order = toString order;
        }
        // (if cmd.requiresUserInput then { RequiresUserInput = "true"; } else { })
      ) cmdList;
    in
    if lib.length ordered > 0 then
      {
        FirstLogonCommands = {
          SynchronousCommand = ordered;
        };
      }
    else
      { };

  # Partitioning options
  diskID = diskConfig.diskID or "0";
  willWipeDisk =
    if diskConfig ? willWipeDisk then (if diskConfig.willWipeDisk then "true" else "false") else "true";
  efiSize = diskConfig.efiSize or 100;
  msrSize = diskConfig.msrSize or 16;
  label = diskConfig.label or "Windows";
  letter = diskConfig.letter or "C";
  installToDisk = diskConfig.installToDisk or diskID;
  installToPartition = diskConfig.installToPartition or "3";

  createPartitionsSpec =
    if diskConfig ? createPartitions && diskConfig.createPartitions != null then
      diskConfig.createPartitions
    else
      [
        {
          "+@wcm:action" = "add";
          Order = "1";
          Type = "EFI";
          Size = toString efiSize;
        }
        {
          "+@wcm:action" = "add";
          Order = "2";
          Type = "MSR";
          Size = toString msrSize;
        }
        {
          "+@wcm:action" = "add";
          Order = "3";
          Type = "Primary";
          Extend = "true";
        }
      ];

  modifyPartitionsSpec =
    if diskConfig ? modifyPartitions && diskConfig.modifyPartitions != null then
      diskConfig.modifyPartitions
    else
      [
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
          Label = label;
          Letter = letter;
        }
      ];

  # OS Image MetaData key/value
  metaDataSpec =
    if imageMetaData != null then
      imageMetaData
    else if imageIndex != null then
      {
        "+@wcm:action" = "add";
        Key = "/IMAGE/INDEX";
        Value = toString imageIndex;
      }
    else
      {
        "+@wcm:action" = "add";
        Key = "/IMAGE/NAME";
        Value = sku;
      };

  # AutoLogon settings
  autoLogonSection =
    if enableAutoLogon && autoLogonUser != null && autoLogonPassword != null then
      {
        AutoLogon = {
          Password = {
            Value = autoLogonPassword;
            PlainText = "true";
          };
          Username = autoLogonUser;
          Enabled = "true";
        }
        // (if autoLogonCount != null then { Logons = toString autoLogonCount; } else { });
      }
    else
      { };

  # User accounts settings
  userAccountsSection =
    let
      adminSection =
        if adminPass != null then
          {
            AdministratorPassword = {
              Value = adminPass;
              PlainText = "true";
            };
          }
        else
          { };

      localSection =
        if lib.length normalizedUsers > 0 then
          {
            LocalAccounts = {
              LocalAccount = map (u: {
                "+@wcm:action" = "add";
                Password = {
                  Value = u.password;
                  PlainText = "true";
                };
                Description = u.description;
                DisplayName = u.displayName;
                Group = u.group;
                Name = u.username;
              }) normalizedUsers;
            };
          }
        else
          { };
    in
    if adminSection != { } || localSection != { } then
      {
        UserAccounts = adminSection // localSection;
      }
    else
      { };

  # LUA / UAC settings section
  offlineServicingPass =
    if enableLUA != null then
      [
        {
          "+@pass" = "offlineServicing";
          component = [
            {
              "+@name" = "Microsoft-Windows-LUA-Settings";
              "+@publicKeyToken" = "31bf3856ad364e35";
              "+@language" = "neutral";
              "+@versionScope" = "nonSxS";
              "+@processorArchitecture" = "amd64";
              EnableLUA = if enableLUA then "true" else "false";
            }
          ];
        }
      ]
    else
      [ ];

  # Build JSON structure for yq XML generation
  jsonStructure = {
    unattend = {
      "+@xmlns" = "urn:schemas-microsoft-com:unattend";
      servicing = "";
      settings = [
        {
          "+@pass" = "windowsPE";
          component = [
            (
              driverPathsComponent
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
                    DiskID = diskID;
                    WillWipeDisk = willWipeDisk;
                    CreatePartitions = {
                      CreatePartition = createPartitionsSpec;
                    };
                    ModifyPartitions = {
                      ModifyPartition = modifyPartitionsSpec;
                    };
                  };
                  WillShowUI = "OnError";
                };

                UserData = {
                  AcceptEula = if acceptEula then "true" else "false";
                  FullName = if primaryUser != null then primaryUser.displayName else "";
                  Organization = registeredOrganization;
                  ProductKey = {
                    Key = if productKey != null then productKey else "";
                    WillShowUI = "Never";
                  };
                };

                ImageInstall = {
                  OSImage = {
                    InstallTo = {
                      DiskID = installToDisk;
                      PartitionID = installToPartition;
                    };
                    WillShowUI = "OnError";
                    InstallToAvailablePartition = "false";
                    InstallFrom = {
                      MetaData = metaDataSpec;
                    };
                  };
                };
              }
              // formatRunSynchronous windowsPESyncCommands
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
      ]
      ++ offlineServicingPass
      ++ [
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

                OOBE = {
                  HideEULAPage = if hideEULAPage then "true" else "false";
                  HideWirelessSetupInOOBE = if hideWirelessSetupInOOBE then "true" else "false";
                  NetworkLocation = oobeNetworkLocation;
                  ProtectYourPC = toString protectYourPC;
                };

                ShowWindowsLive = "false";
              }
              // userAccountsSection
              // autoLogonSection
              // formatFirstLogon firstLogonSyncCommands
              // formatRunSynchronous oobeSystemSyncCommands
            )
          ];
        }
        {
          "+@pass" = "specialize";
          component = [
            (
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
                RegisteredOwner = registeredOwner;
                RegisteredOrganization = registeredOrganization;
              }
              // formatRunSynchronous specializeSyncCommands
            )
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
