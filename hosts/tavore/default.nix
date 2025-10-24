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
    "${nixosModules}/hardware/nas"
  ];

  services = {
    ollama = {
      enable = true;
      models = "/mnt/ollama-models";
      openFirewall = true;
      host = "0.0.0.0";
      port = 11434;
    };
    open-webui = {
      enable = true;
      openFirewall = true;
      host = "0.0.0.0";
      port = 11435;
      environment = let
        t = "True";
        f = "False";
      in {
        ANONYMIZED_TELEMETRY = f;
        DO_NOT_TRACK = t;
        SCARF_NO_ANALYTICS = t;
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";

        ENABLE_SIGNUP = t;
        DEFAULT_USER_ROLE = "pending";
        DEFAULT_LOCALE = "en";
        ENABLE_CHANNELS = t;
        THREAD_POOL_SIZE = "64";
        MODELS_CACHE_TTL = "0";
        ENABLE_REALTIME_CHAT_SAVE = t;
        BYPASS_MODEL_ACCESS_CONTROL = t;
        ENABLE_TITLE_GENERATION = t;
        DEFAULT_PROMPT_SUGGESTIONS = ''
          [
            {
              "title": [
                "Title part 1",
                "Title part 2"
              ],
              "content": "prompt"
            }
          ]'';
      };
    };
  };

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
    cudaForwardCompat = true;
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

  networking = {
  };

  mine.nas = {
    enable = true;
    host = "synology";
    shares = [
      "share-1"
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "25.05";
}
