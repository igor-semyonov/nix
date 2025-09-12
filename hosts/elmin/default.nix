{
  inputs,
  hostname,
  nixosModules,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-gpu-nvidia
    inputs.hardware.nixosModules.common-gpu-nvidia.ada-lovelace
    inputs.hardware.nixosModules.common-pc-ssd

    ./hardware-configuration.nix
    "${nixosModules}/common"
    "${nixosModules}/desktop/kde"
    "${nixosModules}/programs/steam"
    "${nixosModules}/programs/firefox"
    "${nixosModules}/programs/tts"
    "${nixosModules}/programs/nvim"
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
    };
  };

  nixpkgs.config.cudaSupport = true;
  hardware.graphics = {
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

  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
  };
  hardware.nvidia-container-toolkit.enable = true;

  # Set hostname
  networking.hostName = hostname;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "25.05";
}
