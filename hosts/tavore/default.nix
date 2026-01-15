{
  inputs,
  nixosModules,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    # inputs.hardware.nixosModules.common-gpu-nvidia
    # inputs.hardware.nixosModules.common-gpu-nvidia.ada-lovelace
    inputs.hardware.nixosModules.common-pc-ssd

    ./hardware-configuration.nix
    "${nixosModules}/common"
    "${nixosModules}/desktop/kde"
  ];

  nix.settings = {
    download-buffer-size = 128 * 1024 * 1024 * 1024;
    cores = 72;
    max-jobs = 96;
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
  hardware.graphics = {
    enable = true;
  };

  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement = {
      enable = false;
      finegrained = false;
    };
    nvidiaSettings = true;
  };
  hardware.nvidia-container-toolkit.enable = true;

  mine = {
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "25.05";
}
