{
  inputs,
  hostname,
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
    "${nixosModules}/programs/firefox"
    "${nixosModules}/programs/tts"
    # "${nixosModules}/programs/open-audible"
    "${nixosModules}/services/unpatched"
  ];

  nix.settings.download-buffer-size = 48 * 1024 * 1024 * 1024;

  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
    timeout = 5;
    systemd-boot.enable = false;
    grub = {
      efiSupport = true;
      #efiInstallAsRemovable = true; # in case canTouchEfiVariables doesn't work for your system
      device = "nodev";
      fontSize = 64;
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

  nixpkgs.config.cudaSupport = true;
  hardware = {
    graphics = {
      enable = true;
      # extraPackages = with pkgs; [
      # nvidia-vaapi-driver
      # nvtopPackages.nvidia
      # nvidia-docker
      # nvidia-container-toolkit
      # cudaPackages.cudatoolkit
      # cudaPackages.cudnn
      # ];
    };
    nvidia = {
      open = true;
      modesetting.enable = true;
      powerManagement = {
        enable = false;
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

  # Set hostname
  networking = {
    hostName = hostname;
    nftables = {
      enable = true;
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "25.05";
}
