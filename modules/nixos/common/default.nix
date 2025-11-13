{
  inputs,
  outputs,
  lib,
  config,
  userConfig,
  pkgs,
  hostname,
  ...
}: {
  # Nixpkgs configuration
  nixpkgs = {
    overlays = [
      outputs.overlays.stable-packages
      # outputs.overlays.vivaldi
    ];

    config = {
      allowUnfree = true;
    };
  };

  # Register flake inputs for nix commands
  nix.registry = lib.mapAttrs (_: flake: {inherit flake;}) (lib.filterAttrs (_: lib.isType "flake") inputs);

  # Add inputs to legacy channels
  nix.nixPath = ["/etc/nix/path"];
  environment.etc =
    lib.mapAttrs' (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry;

  environment.pathsToLink = ["/share/bash-completion"];

  # Nix settings
  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
    allowed-users = ["@wheel"];
  };

  security.pam = {
    u2f = {
      enable = true;
      control = "sufficient";
      settings = {
        cue = true;
      };
    };
  };

  # Boot settings
  boot = {
    supportedFilesystems = ["ntfs"];

    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = 0;

    # initrd.verbose = false;
    # kernelParams = ["quiet" "splash" "rd.udev.log_level=3"];
    # plymouth.enable = true;

    initrd.verbose = true;
    kernelParams = ["rd.udev.log_level=3"];
    plymouth.enable = false;

    # v4l (virtual camera) module settings
    kernelModules = ["v4l2loopback"];
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
    ];
    extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';
  };

  console = {
    # packages = [pkgs.terminus_font];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-i32b.psf.gz";
    enable = true;
    keyMap = "us";
    earlySetup = true;
    # useXkbConfig = true; # use xkb.options in tty.
  };

  # Networking
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
    nftables = {
      enable = true;
    };
  };

  # Disable systemd services that are affecting the boot time
  systemd.services = {
    NetworkManager-wait-online.enable = false;
    plymouth-quit-wait.enable = false;
  };

  # Timezone
  time.timeZone = "America/New_York";

  # Internationalization
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Enable Wayland support in Chromium and Electron based applications
  # Remove decorations for QT apps
  # Set cursor size
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XCURSOR_SIZE = "96";
  };

  # PATH configuration
  environment.localBinInPath = true;

  # User configuration
  users = {
    users.${userConfig.name} = {
      description = userConfig.fullName;
      extraGroups = ["networkmanager" "wheel" "docker" "i2c"];
      isNormalUser = true;
      shell = pkgs.bash;
      packages = with pkgs; [
        gh
        pass
        dropbox
        dropbox-cli
        cryptomator
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
    groups = {
      i2c = {};
    };
  };

  # Set User's avatar
  system.activationScripts.user-avatar.text = ''
    mkdir -p /var/lib/AccountsService/{icons,users}
    cp ${userConfig.avatar} /var/lib/AccountsService/icons/${userConfig.name}

    touch /var/lib/AccountsService/users/${userConfig.name}

    if ! grep -q "^Icon=" /var/lib/AccountsService/users/${userConfig.name}; then
      if ! grep -q "^\[User\]" /var/lib/AccountsService/users/${userConfig.name}; then
        echo "[User]" >> /var/lib/AccountsService/users/${userConfig.name}
      fi
      echo "Icon=/var/lib/AccountsService/icons/${userConfig.name}" >> /var/lib/AccountsService/users/${userConfig.name}
    fi
  '';

  programs = {
    kdeconnect.enable = true;
    appimage = {
      enable = true;
      binfmt = true;
    };
    gnupg.agent = {
      enable = true;
      settings = {
        default-cache-ttl = 86400;
      };
      pinentryPackage = pkgs.pinentry-curses;
      enableSSHSupport = true;
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    libreoffice-qt6-fresh
    file
    usbutils
    mpv
    terminus_font
    signal-desktop
    lm_sensors
    nix-index
    nom
    btop
    p7zip
    gcc
    glib
    gnumake
    killall
    # vim
    neovim
    wget
    git
    tree
    winePackages.stagingFull
    wireguard-tools
    pcsclite
    pcsc-tools
    opensc
    sxiv
    ( # Wrapper script to tell to Chrome/Chromium to use p11-kit-proxy to load
      # security devices, so they can be used for TLS client auth.
      # Each user needs to run this themselves, it does not work on a system level
      # due to a bug in Chromium:
      #
      # https://bugs.chromium.org/p/chromium/issues/detail?id=16387
      (pkgs.writeShellScriptBin "setup-browser-eid" ''
        NSSDB="''${HOME}/.pki/nssdb"
        mkdir -p ''${NSSDB}

        ${pkgs.nssTools}/bin/modutil -force -dbdir sql:$NSSDB -add p11-kit-proxy \
        -libfile ${pkgs.p11-kit}/lib/p11-kit-proxy.so
      '')
    )
  ];

  services.udev = {
    extraRules = ''
      KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
    '';
    packages = let
      microbitv2 =
        pkgs.writeTextFile
        {
          name = "microbitv2-udev-rule";
          text = ''
            # CMSIS-DAP for microbit
            ACTION!="add|change", GOTO="microbit_rules_end"
            SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", ATTR{idProduct}=="0204", TAG+="uaccess"
            LABEL="microbit_rules_end"
          '';
          destination = "/etc/udev/rules.d/60-microbitv2.rules";
        };
    in [
      microbitv2
    ];
  };

  services = {
    brltty.enable = true;
    ddccontrol.enable = true;
    locate.enable = false;
    pcscd = {
      enable = true;
      plugins = [pkgs.opensc];
    };
    openssh.enable = true;
    libinput.enable = true;
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
      excludePackages = with pkgs; [xterm];
    };
    printing.enable = false;

    # Enable devmon for device management
    devmon.enable = true;
    flatpak.enable = true;
  };

  # Docker configuration
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };
  hardware.nvidia-container-toolkit.enable = true;

  # Fonts configuration
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.meslo-lg
      nerd-fonts.fira-code
      roboto
      liberation_ttf
      lato
      fira
      garamond-libre
      eb-garamond
      helvetica-neue-lt-std
      noto-fonts-color-emoji
      noto-fonts-monochrome-emoji
      noto-fonts-emoji-blob-bin
      openmoji-color
      openmoji-black
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = ["Roboto"];
        serif = ["Garamond Libre"];
        monospace = ["FiraCode Nerd Font"];
        emoji = ["Noto Color Emoji" "Openmoji Color"];
      };
      cache32Bit = true;
    };
    fontDir.enable = true;
  };

  imports = [
    ./sound.nix
    ../programs/nvim
    ../programs/firefox
    ../programs/thunderbird
    ../programs/tts
    ../programs/journal
    ../services/btrbk
    ../services/unpatched
    ../scripts
  ];
}
