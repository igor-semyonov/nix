{
  buildNixosAndHomeManager,
  self,
  config,
  lib,
  ...
}: let
  hostname = "billy";
  system = "x86_64-linux";
  includedUsers = ["igor-headless"];
  nixosHomeManagerModule = true;
  groups = {};
  homeModules = [];
  nixosModules = with self.nixosModules; [
    secrets
    common-headless
    billy-disks

    {
      users.users = {
        # igor-headless.hashedPasswordFile = config.sops.secrets.igor-pw.path;
        root.openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH5gmBdZsP86dXIL7P/Wb+mBtXO/1xqqKMNKKqLr8SJZ igor@boxy"];
      };

      nix = {
        settings = {
          download-buffer-size = 2 * 1024 * 1024 * 1024;
          cores = 1;
          max-jobs = 1;
        };
        # gc = {
        #   automatic = true;
        #   dates = "weekly";
        #   options = "--delete-older-than "; # Deletes generations older than 14 days
        # };
      };

      boot.loader = {
        efi = {
          canTouchEfiVariables = false;
        };
        timeout = 5;
        systemd-boot.enable = false;
        grub = {
          enable = true;
          efiSupport = true;
          # Tells GRUB to write to /boot/EFI/BOOT/BOOTX64.EFI
          efiInstallAsRemovable = true;
          # Set to "nodev" for UEFI, or point to "/dev/vda" if handling BIOS hybrid fallback
          device = "/dev/vda";
          configurationLimit = 10;
        };
      };

      networking = {
        networkmanager.enable = false;
        useNetworkd = true;
        useDHCP = false;
      };
      systemd.network = {
        enable = true;
        networks."10-wan" = {
          matchConfig.Name = "en*";
          networkConfig = {
            # Vultr has no fe80::1; the v6 gateway is a per-VM link-local
            # derived from the NIC's MAC, so it must come from the RA.
            IPv6AcceptRA = true;
          };
          ipv6AcceptRAConfig = {
            # Take the default route from the RA, but not the prefix, so no
            # SLAAC or RFC 4941 temporary addresses appear. The static
            # 2001:19f0:... address stays the only v6 address, and is what
            # the AAAA record points at.
            UseAutonomousPrefix = false;
          };

          address = [
            "207.246.88.247/23"
            "2001:19f0:4000:2c4b:5400:06ff:fe79:e305/64"
          ];
          # v6 default route comes from the RA, not from here.
          routes = [
            {
              Gateway = "207.246.88.1";
              GatewayOnLink = true;
            }
          ];
        };
      };

      zramSwap.enable = true;
      services.journald.extraConfig = ''
        SystemMaxUse=1G
        SystemKeepFree=2G
      '';

      # igix = {
      #   btrbk = {
      #     enable = true;
      #     snapshots.subvolumes = [
      #       "@"
      #       "@home"
      #     ];
      #   };
      # };

      # Apply No-CoW to database and mail directories to prevent BTRFS fragmentation
      systemd.tmpfiles.rules = [
        # "h" means set extended attributes.
        # +C disables CoW.

        # For Vaultwarden (assuming default NixOS state directory)
        "h /var/lib/bitwarden_rs - - - - +C"

        # For Mail (example for standard vmail/dovecot spools)
        "h /var/vmail - - - - +C"
        "h /var/lib/postfix - - - - +C"

        # Create the snapshot directory (Type 'd')
        # Format: Type  Path  Mode  User  Group  Age  Argument
        "d /mnt/btrfs-pool/btrbk-snapshots 0750 root root - -"
      ];

      system.stateVersion = "26.11";
    }
  ];
  nixosVmModules = [
    {config.hardware.nvidia-container-toolkit.enable = lib.mkForce false;}
  ];
  hardware-configuration = {modulesPath, ...}: {
    # Imports standard VirtIO/KVM drivers needed for OVH/Hetzner
    imports = [(modulesPath + "/profiles/qemu-guest.nix")];
  };
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
