{
  pkgs,
  inputs,
  nixosModules,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.common-cpu-amd-zenpower
    # inputs.hardware.nixosModules.common-gpu-nvidia
    inputs.hardware.nixosModules.common-pc-ssd

    ./hardware-configuration.nix
    "${nixosModules}/common"
    "${nixosModules}/desktop/kde"
    "${nixosModules}/programs/steam"
    "${nixosModules}/programs/prismlauncher"
    # "${nixosModules}/programs/open-audible"
  ];

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
      open = true;
      modesetting.enable = true;
      powerManagement = {
        enable = true;
        finegrained = false;
      };
      nvidiaSettings = true;
      # prime.offload = {
      #   enable = false;
      #   enableOffloadCmd = false;
      # };
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
        until ${pkgs.host}/bin/host nalgor.net; do
          sleep 1
        done'';
    # audiobookshelf.preStart = "until ip a s dev fidler; do sleep 1; done; sleep 3";
  };

  networking = {
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

  mine.nas = {
    enable = true;
    host = "synology";
    shares = [
      "share-1"
      "share-2"
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "25.05";
}
