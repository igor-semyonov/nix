{
  pkgs,
  inputs,
  nixosModules,
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

  nixpkgs.config.allowUnfree = true;

  boot = {
    initrd={
      availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
      systemd={
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
    graphics = {
      enable = true;
    };
  };

  networking = {
    firewall = {
    };
    # wg-quick = {
    #   interfaces = {
    #     fidler = {
    #       autostart = true;
    #       address = ["10.0.0.10/32"];
    #       listenPort = 51820;
    #       privateKeyFile = "/etc/wireguard/privatekey";
    #       # postUp = "wg set %i private-key /etc/wireguard/privatekey";
    #       peers = [
    #         {
    #           publicKey = "yPTvlsTZnzAxfn2GxrvSQX5/ymcsSFqSLtHiJ7zJITc=";
    #           allowedIPs = ["10.0.0.0/24"];
    #           endpoint = "nalgor.net:41883";
    #           persistentKeepalive = 25;
    #         }
    #       ];
    #     };
    #   };
    # };
  };

  services.xserver.libinput.enable = true;

  system.stateVersion = "25.11";
}
