{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.common = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = with self.nixosModules; [
      programs-nvim
      programs-thunderbird
      scripts

      ssh
      docker
      ai
      btrbk
      virt
      nas
      console-fonts
      fonts
    ];
    # Nixpkgs configuration
    nixpkgs = {
      overlays = [
        self.overlays.stable-pkgs
        # self.overlays.vivaldi
      ];
      config = {
        allowUnfree = true;
      };
    };

    nix = {
      # Nix settings
      settings = {
        experimental-features = "nix-command flakes";
        auto-optimise-store = true;
        allowed-users = ["@wheel"];
      };
      # Register flake inputs for nix commands
      registry = lib.mapAttrs (_: flake: {inherit flake;}) (lib.filterAttrs (_: lib.isType "flake") inputs);
    };

    # Add inputs to legacy channels
    nix.nixPath = ["/etc/nix/path"];
    environment.etc =
      lib.mapAttrs' (name: value: {
        name = "nix/path/${name}";
        value.source = value.flake;
      })
      config.nix.registry;

    environment.pathsToLink = ["/share/bash-completion"];

    networking = {
      nftables = {
        enable = true;
      };
    };

    # Timezone
    time.timeZone = "America/New_York";

    # Internationalization
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_TIME = "en_GB.UTF-8";
    };

    # PATH configuration
    environment.localBinInPath = true;

    programs = {
      # nh = {
      #   enable = true;
      #   flake = "/home/${userConfig.name}/.config/nix-config";
      # };
      gnupg.agent = {
        enable = true;
        settings = {
          default-cache-ttl = 86400;
        };
        pinentryPackage = pkgs.pinentry-curses;
      };
    };

    # System packages
    environment.systemPackages = with pkgs; [
      e2fsprogs
      pciutils
      usbutils
      file
      terminus_font
      lm_sensors
      nix-index
      nom
      btop
      p7zip
      gcc
      just
      gnumake
      killall
      neovim
      wget
      git
      tree
      wireguard-tools
    ];

    services = {
      locate.enable = false;
    };

    # iincrease open file limits to avoid issues when rebuilding
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "soft";
        item = "nofile";
        value = "8192";
      }
      {
        domain = "*";
        type = "hard";
        item = "nofile";
        value = "65536";
      }
    ];
  };
}
