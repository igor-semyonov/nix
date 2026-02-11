{
  pkgs,
  inputs,
  nixosModules,
  lib,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.apple-macbook-pro-11-5
    # inputs.hardware.nixosModules.common-gpu-amd-southern-islands
    # inputs.hardware.nixosModules.common-pc-ssd

    ./hardware-configuration.nix
    "${nixosModules}/common"
    "${nixosModules}/desktop/kde"
    # "${nixosModules}/desktop/cosmic"
    # "${nixosModules}/desktop/hyprland"
    # "${nixosModules}/programs/steam"
    # "${nixosModules}/programs/prismlauncher"
    # "${nixosModules}/programs/open-audible"
  ];

  nix.settings = {
    download-buffer-size = 12 * 1024 * 1024 * 1024;
    cores = 8;
    max-jobs = 9;
  };

  users = {
    users.kaladin = {
      description = "Kaladin (The Red Frog) Semyonov";
      extraGroups = [
        "networkmanager"
      ];
      isNormalUser = true;
      shell = pkgs.bash;
      packages = with pkgs; [
        zoxide
        python313
        unzip
        starship
        ripgrep
        stable.wl-clipboard
        vivaldi
        vivaldi-ffmpeg-codecs
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  boot = {
    kernelParams = [
      "quiet"
      "splash"
      "rd.udev.log_level=3"
      "brcmfmac.feature_disable=0x82000"
    ];
    extraModprobeConfig = ''
      options brcmfmac roamoff=1
    '';
    plymouth.enable = lib.mkForce true;
    initrd = {
      systemd = {
        enable = true;
        # emergencyAccess = true;
      };
    };
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      timeout = 5;
      systemd-boot.enable = true;
    };
  };

  hardware = {
    enableAllFirmware = true;
    enableAllHardware = true;
    graphics = {
      enable = true;
    };
  };

  networking = {
    networkmanager.wifi.backend = "iwd";
    firewall = {
    };
    wg-quick = {
      interfaces = {
        fidler = {
          autostart = true;
          address = ["10.0.0.11/32"];
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

  programs.nix-ld.enable = lib.mkForce false;
  services.xserver.libinput.enable = true;

  system.stateVersion = "25.11";
}
