{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.common-desktop = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = with self.nixosModules; [
      common
      programs-tts
      programs-journal
      programs-firefox
    ];

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

    networking = {
      networkmanager.enable = true;
    };

    # Disable systemd services that are affecting the boot time
    systemd.services = {
      NetworkManager-wait-online.enable = false;
      plymouth-quit-wait.enable = false;
    };

    # Enable Wayland support in Chromium and Electron based applications
    # Remove decorations for QT apps
    # Set cursor size
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      XCURSOR_SIZE = "96";
    };

    programs = {
      kdeconnect.enable = true;
      appimage = {
        enable = true;
        binfmt = true;
      };
    };

    # System packages
    environment.systemPackages = with pkgs; [
      libreoffice-qt6-fresh
      mpv
      signal-desktop
      winePackages.stagingFull
      pcsclite
      pcsc-tools
      opensc
      sxiv
      # Wrapper script to tell to Chrome/Chromium to use p11-kit-proxy to load
      # security devices, so they can be used for TLS client auth.
      # Each user needs to run this themselves, it does not work on a system level
      # due to a bug in Chromium:
      #
      # https://bugs.chromium.org/p/chromium/issues/detail?id=16387
      (pkgs.writeShellScriptBin "setup-browser-eid" ''
        # shellcheck disable=all
        NSSDB="''${HOME}/.pki/nssdb"
        mkdir -p ''${NSSDB}

        ${pkgs.nssTools}/bin/modutil -force -dbdir sql:$NSSDB -add p11-kit-proxy \
        -libfile ${pkgs.p11-kit}/lib/p11-kit-proxy.so
      '')
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
      # brltty.enable = true;
      ddccontrol.enable = true;
      pcscd = {
        enable = true;
        plugins = [pkgs.opensc];
      };
      libinput = {
        enable = true;
        touchpad.naturalScrolling = false;
      };
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
  };
}
