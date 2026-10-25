{
  buildNixosAndHomeManager,
  inputs,
  self,
  lib,
  ...
}: let
  hostname = "boxy";
  system = "x86_64-linux";
  includedUsers = ["igor"];
  nixosHomeManagerModule = true;
  groups = {"i2c" = {};};
  homeModules = [
    self.homeModules.dropbox
    {
      igix.dropbox = {
        enable = true;
        settleMounts = [
          "/mnt/8tb"
          "/mnt/10tb"
          "/mnt/gentoo-btrfs-pool"
        ];
      };
    }
  ];
  nixosModules = with self.nixosModules; [
    {
      nixpkgs.overlays = [
        (
          final: prev: {
            onnxruntime = prev.onnxruntime.override {
              cudaSupport = false;
            };
            # nixpkgs carries 1.18.4, whose ~60-day self-expiry has passed, so
            # ripping fails with "This application version is too old". Track
            # upstream directly; each release resets that clock.
            makemkv = prev.makemkv.overrideAttrs (finalAttrs: prevAttrs: let
              v = "2.0.0";
              fetch = kind: hash:
                prev.fetchurl {
                  urls = [
                    "https://www.makemkv.com/download/makemkv-${kind}-${v}.tar.gz"
                    "https://www.makemkv.com/download/old/makemkv-${kind}-${v}.tar.gz"
                  ];
                  inherit hash;
                };
            in {
              version = v;
              sourceRoot = "makemkv-oss-${v}";
              srcs = [
                (fetch "bin" "sha256-8SZedIdaGG79+7vsdFmmTpaQM1FeU8vE2AXwo3TwoSQ=")
                (fetch "oss" "sha256-Q1MWstIZ60jIgFJlV63dB2tfXm3lFxQkx2UfnKyVsWE=")
              ];
              passthru =
                prevAttrs.passthru
                // {
                  srcs = {
                    bin = fetch "bin" "sha256-8SZedIdaGG79+7vsdFmmTpaQM1FeU8vE2AXwo3TwoSQ=";
                    oss = fetch "oss" "sha256-Q1MWstIZ60jIgFJlV63dB2tfXm3lFxQkx2UfnKyVsWE=";
                  };
                };
            });
          }
        )
      ];
      networking.firewall.allowedTCPPorts = [2049];
      # Keeps igor's user units alive without a login session. Added for the
      # rootless podman abs-tract container, which has since been removed; left
      # on so any future user-level service does not need it rediscovered.
      users.users.igor.linger = true;
      services.nfs.server = {
        enable = true;
        exports = ''
          # Format: /path/to/share clientIP(options) subnet(options)
          # Example 1: Give a specific Proxmox host full read/write access
          /mnt/8tb/nfs/@no-cow  10.10.20.10(rw,sync,no_subtree_check,no_root_squash)
          /mnt/8tb/nfs/@no-cow  10.10.20.11(rw,sync,no_subtree_check,no_root_squash)

          # Example 2: Give an entire VLAN/subnet read-only access
          # /mnt/storage/media_share    10.0.20.0/24(ro,sync,no_subtree_check)
        '';
      };
    }
    secrets
    igix-desktop

    programs-steam
    programs-prism-launcher

    media-jellyfin
    media-ripping

    uxplay
    u2f
    {igix.u2f.enable = true;}
    {
      igix.sound.devices = {
        fiio-k9 = {};
        questyle-m15i = {};
      };
    }

    # inputs.hardware.nixosModules.common-cpu-amd-zenpower
    # inputs.hardware.nixosModules.common-gpu-nvidia
    inputs.hardware.nixosModules.common-pc-ssd
    (
      {
        pkgs,
        config,
        ...
      }: {
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
            fontSize = lib.mkForce 64;
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
        boot.kernelPackages = lib.mkForce pkgs.linuxPackages_7_2;
        hardware = {
          graphics = {
            enable = true;
          };
          nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
              version = "610.57.04";
              sha256_64bit = "sha256-suk1xmuDuwDAyFe8jg7g/VLekoa0DJzB7sKafOfrEW0=";
              sha256_aarch64 = "sha256-QCefrMBCmpOwuOyXv1k5Gj0iB2CYlPgnG3JToUw/j54=";
              openSha256 = "sha256-rQHOOOY4KL92Ww3KDwh+j4eGU7oNAH8LutZC5wmFnPo=";
              settingsSha256 = "sha256-ZEMo8I8Zc2Tq6RVDNYpAH+f094dUaZiBqO+5f6lIjRI=";
              persistencedSha256 = "sha256-aXmD2VY1RLlgAnlHhOUMWzvMyhI6JTClcFLm4imF/mA=";
            };
            open = true;
            modesetting.enable = true;
            powerManagement = {
              enable = false;
              finegrained = false;
            };
            nvidiaSettings = true;
          };
          nvidia-container-toolkit.enable = true;

          # hardware.printers is deliberately unused: it provisions the queue from
          # cups.service's own ExecStartPost under `set -e`, but `-m everywhere`
          # needs a live IPP query and ipp-usb is ordered After=cups.service, so
          # the query loses the race and a failed lpadmin takes the scheduler down
          # for good via the restart limit. See systemd.services.ensure-printer.
        };

        services = {
          ipp-usb.enable = true;
          printing = {
            enable = lib.mkForce true;
            # Defaults true; cups.socket then owns :631 and cupsd's own IPv4 bind
            # fails, so LAN clients arrive as ::ffff: addresses and miss allowFrom.
            startWhenNeeded = false;
            listenAddresses = ["*:631"];
            # @LOCAL matches any subnet on a local interface, covering both IPv4
            # and the delegated IPv6 /64. A literal v4 subnet 403s anything that
            # reaches cupsd over IPv6.
            allowFrom = ["@LOCAL"];
            defaultShared = true;
            browsing = true;
            openFirewall = true;
            # Defaults to services.avahi.enable; it turns ipp-usb's loopback
            # advertisement into an implicitclass queue that CUPS never re-shares,
            # so AirPrint clients see nothing.
            browsed.enable = false;
          };
          avahi = {
            enable = true;
            # `settings` is freeform — these must be avahi-daemon.conf keys. The
            # old publish.{enable,userServices} names passed through as invalid
            # keys; publishing only worked because ipp-usb still sets the
            # deprecated options and its compat shim flipped disable-publishing.
            settings = {
              # Otherwise boxy.local also publishes the docker bridge addresses
              # and clients resolve the printer's SRV target to 172.17.0.1.
              server.allow-interfaces = ["br0"];
              publish = {
                disable-publishing = false;
                disable-user-service-publishing = false;
                publish-addresses = true;
              };
            };
          };

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
                  --delete \
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
        # services.btrbk.instances.fidler = {
        #   onCalendar = "12:00";
        #   settings = {
        #     timestamp_format = "long";
        #     preserve_day_of_week = "monday";
        #     preserve_hour_of_day = "0";
        #     volume = {
        #       "/mnt/btrfs-pool" = {
        #         snapshot_preserve_min = "latest";
        #         snapshot_preserve = "14d 8w 6m";
        #         snapshot_create = "always";
        #         snapshot_dir = "fidler-snapshots";
        #         subvolume = {
        #           "@fidler" = {};
        #         };
        #       };
        #     };
        #   };
        # };

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
              # shellcheck disable=all
              # shellcheck disable=SC1089,1073,1009
              until "${pkgs.host}/bin/host" nalgor.net; do
                sleep 1
              done
            '';
          # audiobookshelf.preStart = "until ip a s dev fidler; do sleep 1; done; sleep 3";

          # Provisions the queue out-of-band instead of from cups.service, so a
          # printer that is absent or still enumerating can never fail cupsd.
          # Re-run by udev on every USB add, i.e. on boot and on power-cycle.
          ensure-printer = {
            description = "Provision the Canon LBP622C CUPS queue";
            after = ["cups.service" "ipp-usb.service"];
            wants = ["cups.service" "ipp-usb.service"];
            # Catches a fast crash-loop without ever wedging for long: a real
            # attempt takes up to 135s, so it outlives the window and stays
            # retryable. Recovery does not depend on this anyway — udev re-runs
            # the unit when the device reappears.
            startLimitIntervalSec = 300;
            startLimitBurst = 3;
            serviceConfig = {
              Type = "oneshot";
              Restart = "on-failure";
              RestartSec = 15;
              ExecStart = let
                queue = "Canon_LBP622C";
                uri = "ipp://localhost:60000/ipp/print";
              in
                pkgs.writeShellScript "ensure-printer" ''
                  set -eu

                  # ipp-usb binds :60000 before it has enumerated the device, so a
                  # listening socket is not readiness; poll for real attributes.
                  ready=
                  for _ in $(seq 60); do
                    if "${pkgs.cups}/bin/ipptool" -q "${uri}" \
                      "${pkgs.cups}/share/cups/ipptool/get-printer-attributes.test"; then
                      ready=1
                      break
                    fi
                    sleep 2
                  done
                  if [ -z "$ready" ]; then
                    echo "ipp-usb did not serve printer attributes at ${uri}" >&2
                    exit 1
                  fi

                  # retry-job overrides CUPS' stop-printer default, which otherwise
                  # leaves the queue disabled for good once a job meets a printer
                  # that is switched off.
                  "${pkgs.cups}/bin/lpadmin" -p "${queue}" -E \
                    -D 'Canon LBP622C/623C' \
                    -v "${uri}" \
                    -m everywhere \
                    -o printer-is-shared=true \
                    -o printer-error-policy=retry-job
                  "${pkgs.cups}/bin/lpadmin" -d "${queue}"

                  # Separate call: PPD options are applied by rewriting *Default
                  # lines in the queue's current PPD, so the PPD that -m everywhere
                  # regenerates above would discard them.
                  #
                  # The IPP -default attributes are the ones that matter. Building an
                  # everywhere queue copies the device's own job defaults onto it,
                  # and the Canon reports monochrome/one-sided; those stored defaults
                  # outrank the PPD both for AirPrint clients, which read
                  # print-color-mode-default straight off the shared queue, and for
                  # local ones, where print-color-mode maps back onto ColorModel.
                  "${pkgs.cups}/bin/lpadmin" -p "${queue}" \
                    -o print-color-mode-default=color \
                    -o sides-default=two-sided-long-edge \
                    -o ColorModel=RGB \
                    -o Duplex=DuplexNoTumble

                  # Clear any stopped/rejecting state left by jobs that ran while
                  # the printer was unreachable.
                  "${pkgs.cups}/bin/cupsenable" --release "${queue}"
                  "${pkgs.cups}/bin/cupsaccept" "${queue}"
                '';
            };
          };
        };

        networking = {
          firewall = {
            allowedTCPPorts = [8080];
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

        sops.secrets.btrbk-ssh-key = {
          sopsFile = "${inputs.sops-secrets}/boxy.yaml";
          owner = "btrbk";
          mode = "0400";
        };

        sops.secrets = {
          opensubtitles_com_username = {};
          opensubtitles_com_pw = {};
        };

        # subliminal takes provider credentials from the environment, so the
        # two secrets have to arrive as one KEY=VALUE file. A template renders
        # it at activation from the decrypted values, which keeps both out of
        # the store -- interpolating the secrets directly would put them in a
        # world-readable derivation.
        sops.templates."opensubtitles.env" = {
          owner = "media-rip";
          group = "media";
          mode = "0400";
          content = ''
            SUBLIMINAL_PROVIDER_OPENSUBTITLESCOM_USERNAME=${config.sops.placeholder.opensubtitles_com_username}
            SUBLIMINAL_PROVIDER_OPENSUBTITLESCOM_PASSWORD=${config.sops.placeholder.opensubtitles_com_pw}
          '';
        };

        igix = {
          btrbk = {
            enable = true;
            snapshots.volumes."/mnt/btrfs-pool" = ["@" "@home" "@fidler"];
            target = {
              enable = true;
              location = "/mnt/8tb/btrbk-snapshots/";
            };
            pull.billy = {
              host = "ssh.nalgor.com";
              volumes = {
                "/mnt/btrfs-pool-root" = ["@" "@home" "@root" "@var-log"];
                "/mnt/btrfs-pool-data" = ["@var-lib" "@stalwart" "@vaultwarden"];
              };
              target = "/mnt/8tb/billy-backups";
              sshIdentity = config.sops.secrets.btrbk-ssh-key.path;
            };
          };
          nas = {
            enable = false;
          };
          jellyfin.enable = true;
          media-ripping = {
            enable = true;
            allowedUsers = ["igor"];
            # Discs stay in the tray: the desktop automounts them and the rip
            # service cannot unmount another user's mount, so the eject only
            # ever failed noisily.
            eject = false;
            # Installed out of band; see the option description. The free beta
            # key rotates, and each MakeMKV build also self-expires after ~60
            # days, which nixpkgs updates are far too slow to outrun.
            makemkvKeyFile = "/var/lib/media-ripping/makemkv.key";
            # Every rip here is a deliberate rip-tv/rip-movie invocation. Left
            # on, inserting a disc starts a movie-style rip named from the disc
            # label, which for a TV disc means one wrong episode filed as a
            # film -- and the claim that is meant to hold it off cannot be set
            # in time for a disc already in the drive.
            autoRip.enable = false;
            subtitles = {
              languages = ["en" "ko" "ru"];
              credentialsFile = config.sops.templates."opensubtitles.env".path;
              # Blu-rays ship English as embedded PGS, which subliminal counts
              # as covered and skips. PGS is a bitmap: not searchable or
              # restylable, and clients that cannot render it force a burn-in
              # transcode. gestdown and tvsubtitles carry English anonymously,
              # so this costs nothing against the OpenSubtitles quota.
              forceEmbedded = true;
            };
          };
          virtualisation = {
            enable = true;
            hardware-interfaces = ["enp8s0"];
          };
        };

        services.udev.extraRules = ''
          # don't automount my bios save drive
          SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="4C531001460105106550", ENV{UDISKS_IGNORE}="1"

          # Same IPP-over-USB interface match as ipp-usb's own rule (07/01/04).
          # ipp-usb stays running across a printer power-cycle, so its startup is
          # not a usable trigger; bind provisioning to the device instead.
          ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_USB_INTERFACES}=="*:070104:*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ensure-printer.service"
        '';

        system.stateVersion = "25.05";
      }
    )
  ];
  nixosVmModules = [
    {config.hardware.nvidia-container-toolkit.enable = lib.mkForce false;}
  ];
  hardware-configuration = (
    {
      config,
      lib,
      ...
    }: let
      username = "igor";
    in {
      # imports = [
      #   (modulesPath + "/installer/scan/not-detected.nix")
      # ];

      boot.initrd.availableKernelModules = [];
      boot.initrd.kernelModules = [];
      boot.kernelModules = ["kvm-amd"];
      boot.extraModulePackages = [];

      fileSystems = let
        btrfs-options = [
          "noautodefrag"
          "noatime"
          "discard=async"
          "compress=zstd:5"
          "commit=30"
        ];
        btrfs-nonprimary-options =
          btrfs-options
          ++ btrfs-delay-options
          ++ [
            "x-systemd.idle-timeout=60s"
          ];
        btrfs-delay-options = [
          "nofail"
          "noauto"
          "x-systemd.automount"
          "x-systemd.device-timeout=5s"
        ];
        btrfs-options-hdd =
          [
            "autodefrag"
            "noatime"
            "commit=60"
            "compress=zstd:7"
            "x-systemd.idle-timeout=120s"
          ]
          ++ btrfs-delay-options;
        disk-main = "/dev/disk/by-uuid/081a7b33-1e90-4885-90b7-7611d38f04dd";
        disk-8tb = "/dev/disk/by-uuid/2d0abc72-8189-41f4-bf6a-990a20bcadd1";
        disk-gentoo = "/dev/disk/by-uuid/11a22b3d-fa0c-4821-8bf0-802b5d983c7e";
        disk-10tb = "/dev/disk/by-uuid/a11033d4-a88b-4c02-8ba7-9a36ba9c6df8";
        disk-esp = "/dev/disk/by-uuid/A3CA-824C";

        fsType = "btrfs";
        noCheck = true;
      in {
        "/" = {
          inherit fsType noCheck;
          device = disk-main;
          options = ["subvol=@"] ++ btrfs-options;
        };
        "/nix" = {
          inherit fsType noCheck;
          device = disk-main;
          options = ["subvol=@nix"] ++ btrfs-options;
        };
        "/home" = {
          inherit fsType noCheck;
          device = disk-main;
          options = ["subvol=@home"] ++ btrfs-options;
        };
        "/mnt/btrfs-pool" = {
          inherit fsType noCheck;
          device = disk-main;
          options = ["subvolid=5"] ++ btrfs-options;
        };
        "/mnt/8tb" = {
          inherit fsType noCheck;
          device = disk-8tb;
          options = ["subvolid=5"] ++ btrfs-nonprimary-options;
        };
        "/home/${username}/data" = {
          inherit fsType noCheck;
          device = disk-8tb;
          options = ["subvol=@data"] ++ btrfs-nonprimary-options;
        };
        "/home/${username}/games" = {
          inherit fsType noCheck;
          device = disk-8tb;
          options = ["subvol=@games"] ++ btrfs-nonprimary-options;
        };
        "/var/lib/libvirt/images" = {
          inherit fsType noCheck;
          device = disk-8tb;
          options = ["subvol=@vm-images"] ++ btrfs-nonprimary-options;
        };
        "/mnt/gentoo-btrfs-pool" = {
          inherit fsType noCheck;
          device = disk-gentoo;
          options = ["subvolid=5"] ++ btrfs-nonprimary-options;
        };
        "/mnt/10tb" = {
          inherit fsType noCheck;
          device = disk-10tb;
          options = ["subvolid=5"] ++ btrfs-options-hdd;
        };
        "/boot/efi" = {
          device = disk-esp;
          fsType = "vfat";
          options = ["fmask=0022" "dmask=0022"];
        };
      };

      swapDevices = [
        {device = "/dev/disk/by-uuid/7164217e-8875-4bae-babe-e5907c62467c";}
      ];

      # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
      # (the default) this is the recommended approach. When using systemd-networkd it's
      # still possible to use this option, but it's recommended to use it in conjunction
      # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
      networking.useDHCP = lib.mkDefault true;
      # networking.interfaces.br-99c977bb52ae.useDHCP = lib.mkDefault true;
      # networking.interfaces.br-e70c0689d26d.useDHCP = lib.mkDefault true;
      # networking.interfaces.br-f5c24df0f12b.useDHCP = lib.mkDefault true;
      # networking.interfaces.docker0.useDHCP = lib.mkDefault true;
      # networking.interfaces.dummy0.useDHCP = lib.mkDefault true;
      # networking.interfaces.enp7s0.useDHCP = lib.mkDefault true;
      # networking.interfaces.enp8s0.useDHCP = lib.mkDefault true;
      # networking.interfaces.fidler.useDHCP = lib.mkDefault true;
      # networking.interfaces.sit0.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth10460c8.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth366e19a.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth3af2356.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth40d738f.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth531d6bb.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth61afc6d.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth7d78d85.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth8137433.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth86c7325.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth88da642.useDHCP = lib.mkDefault true;
      # networking.interfaces.veth8f1377c.useDHCP = lib.mkDefault true;
      # networking.interfaces.vethb3808aa.useDHCP = lib.mkDefault true;
      # networking.interfaces.vethde31624.useDHCP = lib.mkDefault true;
      # networking.interfaces.vethe4a87ad.useDHCP = lib.mkDefault true;
      # networking.interfaces.virbr0.useDHCP = lib.mkDefault true;
      # networking.interfaces.wlp6s0.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    }
  );
  result = buildNixosAndHomeManager {
    inherit
      system
      hostname
      includedUsers
      groups
      hardware-configuration
      nixosHomeManagerModule
      nixosModules
      nixosVmModules
      homeModules
      ;
  };
in {inherit (result) flake perSystem;}
