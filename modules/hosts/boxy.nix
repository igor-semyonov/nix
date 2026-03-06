{
  buildNixosAndHomeManager,
  inputs,
  self,
  config,
  lib,
  ...
}: let
  ns = config.namespace-specifier;
  hostname = "boxy";
  system = "x86_64-linux";
  includedUsers = ["igor"];
  groups = {"i2c" = {};};
  homeModules = [
    {
      programs.home-manager.enable = true;
      home.stateVersion = "25.05";
    }
    self.homeModules.nixpkgs
  ];
  nixosModules = with self.nixosModules; [
    {
      services.actual = {
        enable = true;
      };
    }
    secrets
    common

    kde
    hyprland

    programs-steam
    programs-prism-launcher

    nix-ld
    uxplay
    u2f
    {igix.u2f.enable = true;}
    sound-fiio-k9

    inputs.hardware.nixosModules.common-cpu-amd-zenpower
    # inputs.hardware.nixosModules.common-gpu-nvidia
    inputs.hardware.nixosModules.common-pc-ssd
    (
      {
        pkgs,
        config,
        ...
      }: {
        nix.settings = {
          download-buffer-size = 48 * 1024 * 1024 * 1024;
          cores = 32;
          max-jobs = 48;
        };

        boot.loader = {
          efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot/efi";
          };
          timeout = 5;
          systemd-boot.enable = false;
          grub = {
            efiSupport = true;
            # efiInstallAsRemovable = true; # in case canTouchEfiVariables doesn't work for your system
            device = "nodev";
            font = "${pkgs.fira-code}/share/fonts/truetype/FiraCode-VF.ttf";
            fontSize = 128;
            entryOptions = "--class nixos --unrestricted --id nixos";
            default = "nixos";
            # default="gentoo";
            extraConfig = ''
              if [ -f  ''${config_directory}/custom.cfg ]; then
                source ''${config_directory}/custom.cfg
              fi
            '';
            memtest86.enable = true;
            extraEntries = ''
              menuentry "UEFI Firmware Settings" {
                fwsetup
              }
            '';
          };
        };

        nixpkgs.config = {
          cudaSupport = true;
          cudaCapabilities = ["8.9"];
          cudaForwardCompat = false;
        };
        hardware = {
          graphics = {
            enable = true;
          };
          nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.latest;
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

        services = {
          xserver.videoDrivers = ["nvidia"];
          audiobookshelf = {
            enable = true;
            host = "10.0.0.10";
            # host="0.0.0.0";
            port = 13378;
            openFirewall = true;
          };
        };

        # backing up fidler
        systemd = {
          timers = {
            backup-fidler = {
              description = "Backup fidler timer";
              wantedBy = ["timers.target"];
              partOf = ["backup-fidler.service"];
              timerConfig.OnCalendar = "03:00";
              timerConfig.Persistent = "true";
            };
            backup-audiobooks = {
              description = "Backup audiobooks timer";
              wantedBy = ["timers.target"];
              partOf = ["backup-audiobooks.service"];
              timerConfig.OnCalendar = "05:00";
              timerConfig.Persistent = "true";
            };
          };
          services = {
            backup-audiobooks = {
              description = "Run backup of audiobooks";
              path = with pkgs; [bash rsync openssh];
              serviceConfig = {
                Type = "exec";
              };
              script =
                /*
                bash
                */
                ''
                  rsync \
                  -ahP \
                  /mnt/10tb/OpenAudible/books/* \
                  igor@synology.local:/volume4/share-2/audiobookshelf/audiobooks/.
                  rsync \
                  -ahP \
                  /var/lib/audiobookshelf/* \
                  igor@synology.local:/volume4/share-2/audiobookshelf/.
                '';
            };
            backup-fidler = {
              description = "Run backup of fidler";
              path = with pkgs; [bash rsync openssh];
              serviceConfig.Type = "exec";
              script =
                /*
                bash
                */
                ''
                  rsync \
                  -ahPHAX \
                  --exclude sys  \
                  --exclude dev  \
                  --exclude proc \
                  --delete \
                  10.0.0.1:/*  \
                  /mnt/btrfs-pool/@fidler/.
                '';
            };
          };
        };
        services.btrbk.instances.fidler = {
          onCalendar = "12:00";
          settings = {
            timestamp_format = "long";
            preserve_day_of_week = "monday";
            preserve_hour_of_day = "0";
            volume = {
              "/mnt/btrfs-pool" = {
                snapshot_preserve_min = "latest";
                snapshot_preserve = "14d 8w 6m";
                snapshot_create = "always";
                snapshot_dir = "fidler-snapshots";
                subvolume = {
                  "@fidler" = {};
                };
              };
            };
          };
        };

        systemd.services = {
          # dns-available = {
          #   enable = true;
          #   description = "Ensure DNS lookup is working";
          #   after = ["network-online.target"];
          #   # postStart = "until host nalgor.net; do sleep 1; done;";
          #   wantedBy = ["multi-user.target"];
          #   serviceConfig = {
          #     Type = "oneshot";
          #     ExecStart = "${pkgs.bash}/bin/bash -c 'until host nalgor.net; do sleep 1; done'";
          #   };
          # };
          # wg-quick-fidler.after = ["nss-lookup.target"];
          audiobookshelf.after = ["wg-quick-fidler.service"];
          wg-quick-fidler.preStart =
            /*
            bash
            */
            ''
              # shellcheck disable=all
              # shellcheck disable=SC1089,1073,1009
              until "${pkgs.host}/bin/host" nalgor.net; do
                sleep 1
              done
            '';
          # audiobookshelf.preStart = "until ip a s dev fidler; do sleep 1; done; sleep 3";
        };

        networking = {
          firewall = {
            allowedTCPPorts = [8080];
          };
          wg-quick = {
            interfaces = {
              fidler = {
                autostart = true;
                address = ["10.0.0.10/32"];
                listenPort = 51820;
                privateKeyFile = "/etc/wireguard/privatekey";
                # postUp = "wg set %i private-key /etc/wireguard/privatekey";
                peers = [
                  {
                    publicKey = "yPTvlsTZnzAxfn2GxrvSQX5/ymcsSFqSLtHiJ7zJITc=";
                    allowedIPs = ["10.0.0.0/24"];
                    endpoint = "nalgor.net:41883";
                    persistentKeepalive = 25;
                  }
                ];
              };
            };
          };
        };

        ${ns} = {
          btrbk.enable = true;
          nas = {
            enable = true;
            host = "synology";
            shares = [
              "share-1"
              "share-2"
            ];
          };
          virtualisation = {
            enable = true;
            hardware-interfaces = ["enp8s0"];
          };
        };

        services.udev.extraRules = ''
          # don't automount my bios save drive
          SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="4C531001460105106550", ENV{UDISKS_IGNORE}="1"
        '';

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
      ...
    }: let
      username = "igor";
      btrfs-options = ["noautodefrag" "noatime" "compress-force=zstd:7" "commit=60"];
      btrfs-options-hdd = ["autodefrag" "noatime" "compress-force=zstd:7" "commit=60"];
    in {
      # imports = [
      #   (modulesPath + "/installer/scan/not-detected.nix")
      # ];

      boot.initrd.availableKernelModules = [];
      boot.initrd.kernelModules = [];
      boot.kernelModules = ["kvm-amd"];
      boot.extraModulePackages = [];

      fileSystems = {
        "/" = {
          device = "/dev/disk/by-uuid/081a7b33-1e90-4885-90b7-7611d38f04dd";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@"] ++ btrfs-options;
        };
        "/nix" = {
          device = "/dev/disk/by-uuid/081a7b33-1e90-4885-90b7-7611d38f04dd";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@nix"] ++ btrfs-options;
        };
        "/home" = {
          device = "/dev/disk/by-uuid/081a7b33-1e90-4885-90b7-7611d38f04dd";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@home"] ++ btrfs-options;
        };
        "/mnt/btrfs-pool" = {
          device = "/dev/disk/by-uuid/081a7b33-1e90-4885-90b7-7611d38f04dd";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvolid=5"] ++ btrfs-options;
        };
        "/mnt/8tb" = {
          device = "/dev/disk/by-uuid/2d0abc72-8189-41f4-bf6a-990a20bcadd1";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvolid=5"] ++ btrfs-options;
        };
        "/home/${username}/data" = {
          device = "/dev/disk/by-uuid/2d0abc72-8189-41f4-bf6a-990a20bcadd1";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@data"] ++ btrfs-options;
        };
        "/home/${username}/games" = {
          device = "/dev/disk/by-uuid/2d0abc72-8189-41f4-bf6a-990a20bcadd1";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvol=@games"] ++ btrfs-options;
        };
        "/mnt/gentoo-btrfs-pool" = {
          device = "/dev/disk/by-uuid/11a22b3d-fa0c-4821-8bf0-802b5d983c7e";
          fsType = "btrfs";
          noCheck = true;
          options = ["subvolid=5"] ++ btrfs-options;
        };
        "/mnt/10tb" = {
          device = "/dev/disk/by-uuid/a11033d4-a88b-4c02-8ba7-9a36ba9c6df8";
          fsType = "btrfs";
          noCheck = true;
          options =
            [
              "subvolid=5"
              "noauto"
              "x-systemd.automount"
              # "x-systemd.idle-timeout=10m"
            ]
            ++ btrfs-options-hdd;
        };
        "/boot/efi" = {
          device = "/dev/disk/by-uuid/A3CA-824C";
          fsType = "vfat";
          options = ["fmask=0022" "dmask=0022"];
        };
      };

      swapDevices = [
        {device = "/dev/disk/by-uuid/7164217e-8875-4bae-babe-e5907c62467c";}
      ];

      # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
      # (the default) this is the recommended approach. When using systemd-networkd it's
      # still possible to use this option, but it's recommended to use it in conjunction
      # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
      networking.useDHCP = lib.mkDefault true;
      # networking.interfaces.br-99c977bb52ae.useDHCP = lib.mkDefault true;
      # networking.interfaces.br-e70c0689d26d.useDHCP = lib.mkDefault true;
      # networking.interfaces.br-f5c24df0f12b.useDHCP = lib.mkDefault true;
      # networking.interfaces.docker0.useDHCP = lib.mkDefault true;
      # networking.interfaces.dummy0.useDHCP = lib.mkDefault true;
      # networking.interfaces.enp7s0.useDHCP = lib.mkDefault true;
      # networking.interfaces.enp8s0.useDHCP = lib.mkDefault true;
      # networking.interfaces.fidler.useDHCP = lib.mkDefault true;
      # networking.interfaces.sit0.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth10460c8.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth366e19a.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth3af2356.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth40d738f.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth531d6bb.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth61afc6d.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth7d78d85.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth8137433.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth86c7325.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth88da642.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth8f1377c.useDHCP = lib.mkDefault true;
      # networking.interfaces.vethb3808aa.useDHCP = lib.mkDefault true;
      # networking.interfaces.vethde31624.useDHCP = lib.mkDefault true;
      # networking.interfaces.vethe4a87ad.useDHCP = lib.mkDefault true;
      # networking.interfaces.virbr0.useDHCP = lib.mkDefault true;
      # networking.interfaces.wlp6s0.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    }
  );
  result = buildNixosAndHomeManager {
    inherit
      system
      hostname
      includedUsers
      groups
      hardware-configuration
      nixosModules
      nixosVmModules
      homeModules
      ;
  };
in {inherit (result) flake perSystem;}
