{
  buildNixosAndHomeManager,
  inputs,
  self,
  config,
  lib,
  ...
}: let
  ns = config.namespace-specifier;
  hostname = "tavore";
  system = "x86_64-linux";
  includedUsers = ["igor"];
  nixosHomeManagerModule = true;
  groups = {"i2c" = {};};
  homeModules = [
    {
      programs.home-manager.enable = true;
      home.stateVersion = "25.05";
    }
    # self.homeModules.nixpkgs # only if home manager is used standalone
  ];
  nixosModules = with self.nixosModules; [
    common

    kde

    nix-ld
    uxplay
    u2f
    {igix.u2f.enable = true;}
    sound-fiio-k9

    inputs.hardware.nixosModules.common-cpu-intel
    # inputs.hardware.nixosModules.common-gpu-nvidia
    inputs.hardware.nixosModules.common-pc-ssd
    (
      {...}: {
        nix.settings = {
          download-buffer-size = 192 * 1024 * 1024 * 1024;
          cores = 72;
          max-jobs = 72;
        };

        boot.loader = {
          efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot/efi";
          };
          timeout = 5;
          systemd-boot = {
            enable = true;
            memtest86.enable = true;
            extraEntries = {
              "fedora.conf" = ''
                title Fedora
                efi /EFI/fedora/grubx64.efi
                sort-key a_fedora
              '';
            };
          };
        };

        nixpkgs.config = {
          cudaSupport = true;
          cudaCapabilities = ["8.6"];
          cudaForwardCompat = false;
        };

        services.xserver.videoDrivers = ["nvidia"];
        hardware = {
          graphics = {
            enable = true;
          };
          nvidia = {
            open = true;
            modesetting.enable = true;
            powerManagement = {
              enable = false;
              finegrained = false;
            };
            nvidiaSettings = true;
          };
          nvidia-container-toolkit.enable = true;
        };

        ${ns} = {
          btrbk.enable = true;
          nas = {
            enable = true;
            host = "synology";
            shares = [
              "share-1"
            ];
          };
          ai = {
            ollama.enable = true;
            open-webui.enable = false;
          };
          virtualisation = {
            enable = true;
            hardware-interfaces = ["eno2np1"];
          };
        };

        boot.binfmt.emulatedSystems = ["aarch64-linux"];
        nix.settings.trusted-users = includedUsers;

        system.stateVersion = "25.05";
      }
    )
  ];
  nixosVmModules = [
    {config.hardware.nvidia-container-toolkit.enable = lib.mkForce false;}
  ];
  hardware-configuration = (
    {
      config,
      lib,
      modulesPath,
      ...
    }: let
      btrfs-options = ["noautodefrag" "noatime" "compress-force=zstd:7" "commit=60"];
      # btrfs-options-hdd = ["autodefrag" "noatime" "compress-force=zstd:7" "commit=60"];
    in {
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid"];
      boot.initrd.kernelModules = [];
      boot.kernelModules = ["kvm-intel"];
      boot.extraModulePackages = [];

      fileSystems = {
        "/" = {
          device = "/dev/disk/by-uuid/56836784-c98e-43b7-b349-1e125ff66fa7";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@"] ++ btrfs-options;
        };
        "/home" = {
          device = "/dev/disk/by-uuid/56836784-c98e-43b7-b349-1e125ff66fa7";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@home"] ++ btrfs-options;
        };
        "/nix" = {
          device = "/dev/disk/by-uuid/56836784-c98e-43b7-b349-1e125ff66fa7";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@nix"];
        };
        "/mnt/btrfs-pool" = {
          device = "/dev/disk/by-uuid/56836784-c98e-43b7-b349-1e125ff66fa7";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvolid=5"] ++ btrfs-options;
        };

        "/boot/efi" = {
          device = "/dev/disk/by-uuid/D203-132D";
          fsType = "vfat";
          options = ["fmask=0077" "dmask=0077"];
        };

        "/mnt/ssd" = {
          device = "/dev/disk/by-uuid/16f331fb-188f-4362-8f28-00fbb333304a";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvolid=5"] ++ btrfs-options;
        };
        "/data" = {
          device = "/dev/disk/by-uuid/16f331fb-188f-4362-8f28-00fbb333304a";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@data"] ++ btrfs-options;
        };
        "/mnt/ollama-models" = {
          device = "/dev/disk/by-uuid/16f331fb-188f-4362-8f28-00fbb333304a";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@ollama-models"] ++ btrfs-options;
        };
      };

      swapDevices = [];

      # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
      # (the default) this is the recommended approach. When using systemd-networkd it's
      # still possible to use this option, but it's recommended to use it in conjunction
      # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
      networking.useDHCP = lib.mkDefault true;
      # networking.interfaces.br-73ced3702a00.useDHCP = lib.mkDefault true;
      # networking.interfaces.docker0.useDHCP = lib.mkDefault true;
      # networking.interfaces.eno2np1.useDHCP = lib.mkDefault true;
      # networking.interfaces.eno3np0.useDHCP = lib.mkDefault true;
      # networking.interfaces.vethf136b10.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    }
  );
  result = buildNixosAndHomeManager {
    inherit
      system
      hostname
      includedUsers
      groups
      hardware-configuration
      nixosHomeManagerModule
      nixosModules
      nixosVmModules
      homeModules
      ;
  };
in {inherit (result) flake perSystem;}
