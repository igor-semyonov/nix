{
  buildNixos,
  inputs,
  self,
  lib,
  ...
}: let
  hostname = "leto";
  system = "x86_64-linux";
  # includedUsers = ["igor" "kaladin"];
  includedUsers = ["igor"];
  groups = {};
  nixosHomeManagerModule = true;
  homeModules = [
  ];
  nixosModules = with self.nixosModules; [
    common
    secrets
    wifi
    {
      igix.wifi = {
        enable = true;
        key-mgmt = "wpa-psk";
      };
    }

    kde

    programs-prism-launcher

    uxplay
    u2f

    inputs.hardware.nixosModules.apple-macbook-pro-11-5
    # inputs.hardware.nixosModules.common-gpu-amd-southern-islands
    # inputs.hardware.nixosModules.common-pc-ssd
    (
      {...}: {
        nix.settings = {
          download-buffer-size = 12 * 1024 * 1024 * 1024;
          cores = 8;
          max-jobs = 8;
        };

        nix.trustedUsers = includedUsers;

        boot = {
          kernelParams = [
            "quiet"
            "splash"
            "rd.udev.log_level=3"
            "brcmfmac.feature_disable=0x82000"
            "8250.nr_uarts=0"
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
            luks.devices =
              lib.genAttrs [
                "luks-4438f2b3-0e46-4942-8896-b8d984265655"
                "luks-a478d497-5266-483f-b27e-5585b8035dfa"
              ]
              (_: {crypttabExtraOpts = ["fido2-device=auto"];});
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

        nixpkgs.config = {
          cudaSupport = false;
        };

        hardware = {
          bluetooth = {
            enable = true;
            powerOnBoot = true;
          };
          # firmware = [
          #   (pkgs.stdenvNoCC.mkDerivation {
          #     name = "broadcom-mac-wifi-firmware";
          #     # Fetching a community-hosted copy of the Apple NVRAM text file
          #     # src = pkgs.fetchurl {
          #     #   url = "https://raw.githubusercontent.com/dali99/macbookpro11-4/master/brcmfmac43602-pcie.txt";
          #     #   hash = "";
          #     # };
          #     src = pkgs.fetchurl {
          #       url = "https://gist.githubusercontent.com/cristianmiranda/ba9d64b4324f0803d9422d765de62252/raw/brcmfmac43602-pcie.txt";
          #       hash = "sha256-+86fiYd1nurBLjbXJjfQgJRRV6lcZsKc6C28nKobGKE=";
          #     };
          #     dontUnpack = true;
          #     installPhase = ''
          #       mkdir -p $out/lib/firmware/brcm

          #       # The kernel specifically requested this file name in your dmesg logs
          #       cp $src "$out/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro11,5.txt"

          #       # Also create the generic fallback name just in case
          #       cp $src $out/lib/firmware/brcm/brcmfmac43602-pcie.txt
          #     '';
          #   })
          # ];
          enableAllFirmware = true;
          enableAllHardware = true;
          graphics = {
            enable = true;
          };
        };

        networking = {
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

        system.stateVersion = "25.11";
      }
    )
  ];
  hardware-configuration = (
    {
      config,
      lib,
      modulesPath,
      ...
    }: {
      imports = [
        (modulesPath + "/hardware/network/broadcom-43xx.nix")
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
      boot.initrd.kernelModules = [];
      boot.kernelModules = ["kvm-intel"];

      fileSystems."/" = {
        device = "/dev/mapper/luks-4438f2b3-0e46-4942-8896-b8d984265655";
        fsType = "ext4";
      };

      boot.initrd.luks.devices."luks-4438f2b3-0e46-4942-8896-b8d984265655".device = "/dev/disk/by-uuid/4438f2b3-0e46-4942-8896-b8d984265655";
      boot.initrd.luks.devices."luks-a478d497-5266-483f-b27e-5585b8035dfa".device = "/dev/disk/by-uuid/a478d497-5266-483f-b27e-5585b8035dfa";

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/87BB-6093";
        fsType = "vfat";
        options = ["fmask=0077" "dmask=0077"];
      };

      swapDevices = [
        {device = "/dev/mapper/luks-a478d497-5266-483f-b27e-5585b8035dfa";}
      ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    }
  );
  result = buildNixos {
    inherit
      system
      hostname
      includedUsers
      groups
      hardware-configuration
      nixosHomeManagerModule
      nixosModules
      homeModules
      ;
  };
in {inherit (result) flake perSystem;}
