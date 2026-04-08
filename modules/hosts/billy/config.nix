{
  buildNixosAndHomeManager,
  inputs,
  self,
  config,
  lib,
  ...
}: let
  ns = config.namespace-specifier;
  hostname = "billy";
  system = "x86_64-linux";
  includedUsers = ["igor"];
  nixosHomeManagerModule = true;
  groups = {};
  homeModules = [
    {
      programs.home-manager.enable = true;
      home.stateVersion = "25.11";
    }
    # self.homeModules.nixpkgs # only if home manager is used standalone
  ];
  nixosModules = with self.nixosModules; [
    secrets
    common-headless
    billy-disks

    (
      {
        pkgs,
        config,
        ...
      }: {
        nix.settings = {
          download-buffer-size = 1 * 1024 * 1024 * 1024;
          cores = 2;
          max-jobs = 2;
        };
        networking = {
          networkmanager.enable = false;
          useNetworkd = true;
          useDHCP = false;
        };
        systemd.network = {
          enable = true;
          networks."10-wan" = {
            # Match the name of your Hetzner interface (check with `ip a` or `ifconfig`)
            matchConfig.Name = "eth0";

            # Hetzner Cloud provides IPv4 via DHCP
            networkConfig.DHCP = "ipv4";

            # Accept Router Advertisements for IPv6
            networkConfig.IPv6AcceptRA = true;
          };
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
            configurationLimit = 10;
          };
        };

        networking = {
          # wg-quick = {
          #   interfaces = {
          #     main = {
          #       autostart = true;
          #       address = ["10.1.0.0/32"];
          #       listenPort = 46734;
          #       privateKeyFile = "/etc/wireguard/privatekey";
          #       # postUp = "wg set %i private-key /etc/wireguard/privatekey";
          #       peers = [
          #         {
          #           publicKey = "c6VN95sqkyoogYpDzSGCs7NnacEId5EoVsUIUlB19Cw=";
          #           allowedIPs = ["10.1.0.0/24"];
          #         }
          #       ];
          #     };
          #   };
          # };
        };

        ${ns} = {
          btrbk.enable = true;
        };

        system.stateVersion = "25.11";
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
      ...
    }: let
      username = "igor";
      btrfs-options = ["noautodefrag" "noatime" "compress-force=zstd:7" "commit=60"];
      btrfs-options-hdd = ["autodefrag" "noatime" "compress-force=zstd:7" "commit=60"];
    in {
      # # imports = [
      # #   (modulesPath + "/installer/scan/not-detected.nix")
      # # ];

      # boot.initrd.availableKernelModules = [];
      # boot.initrd.kernelModules = [];
      # boot.kernelModules = [];
      # boot.extraModulePackages = [];

      # fileSystems = {
      #   "/" = {
      #     device = "/dev/disk/by-uuid/081a7b33-1e90-4885-90b7-7611d38f04dd";
      #     fsType = "btrfs";
      #     noCheck = true;
      #     options = ["subvol=@"] ++ btrfs-options;
      #   };
      #   "/nix" = {
      #     device = "/dev/disk/by-uuid/081a7b33-1e90-4885-90b7-7611d38f04dd";
      #     fsType = "btrfs";
      #     noCheck = true;
      #     options = ["subvol=@nix"] ++ btrfs-options;
      #   };
      #   "/home" = {
      #     device = "/dev/disk/by-uuid/081a7b33-1e90-4885-90b7-7611d38f04dd";
      #     fsType = "btrfs";
      #     noCheck = true;
      #     options = ["subvol=@home"] ++ btrfs-options;
      #   };
      #   "/mnt/btrfs-pool" = {
      #     device = "/dev/disk/by-uuid/081a7b33-1e90-4885-90b7-7611d38f04dd";
      #     fsType = "btrfs";
      #     noCheck = true;
      #     options = ["subvolid=5"] ++ btrfs-options;
      #   };
      #   "/mnt/8tb" = {
      #     device = "/dev/disk/by-uuid/2d0abc72-8189-41f4-bf6a-990a20bcadd1";
      #     fsType = "btrfs";
      #     noCheck = true;
      #     options = ["subvolid=5"] ++ btrfs-options;
      #   };
      #   "/home/${username}/data" = {
      #     device = "/dev/disk/by-uuid/2d0abc72-8189-41f4-bf6a-990a20bcadd1";
      #     fsType = "btrfs";
      #     noCheck = true;
      #     options = ["subvol=@data"] ++ btrfs-options;
      #   };
      #   "/home/${username}/games" = {
      #     device = "/dev/disk/by-uuid/2d0abc72-8189-41f4-bf6a-990a20bcadd1";
      #     fsType = "btrfs";
      #     noCheck = true;
      #     options = ["subvol=@games"] ++ btrfs-options;
      #   };
      #   "/mnt/gentoo-btrfs-pool" = {
      #     device = "/dev/disk/by-uuid/11a22b3d-fa0c-4821-8bf0-802b5d983c7e";
      #     fsType = "btrfs";
      #     noCheck = true;
      #     options = ["subvolid=5"] ++ btrfs-options;
      #   };
      #   "/mnt/10tb" = {
      #     device = "/dev/disk/by-uuid/a11033d4-a88b-4c02-8ba7-9a36ba9c6df8";
      #     fsType = "btrfs";
      #     noCheck = true;
      #     options =
      #       [
      #         "subvolid=5"
      #         "noauto"
      #         "x-systemd.automount"
      #         # "x-systemd.idle-timeout=10m"
      #       ]
      #       ++ btrfs-options-hdd;
      #   };
      #   "/boot/efi" = {
      #     device = "/dev/disk/by-uuid/A3CA-824C";
      #     fsType = "vfat";
      #     options = ["fmask=0022" "dmask=0022"];
      #   };
      # };

      # networking.useDHCP = lib.mkDefault true;

      # nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
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
