{
  buildNixosAndHomeManager,
  self,
  config,
  inputs,
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
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
        };
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
          # devices is left to disko, which sets it from the EF02 partition.
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
      virtualisation.docker.enable = false;

      services.openssh.settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
      };

      services.journald.extraConfig = ''
        SystemMaxUse=1G
        SystemKeepFree=2G
      '';

      igix.btrbk = {
        enable = true;
        # @nix, @swap, @tmp, @var-tmp and @var-cache are deliberately absent.
        snapshots.volumes = {
          "/mnt/btrfs-pool-root" = ["@" "@home" "@root" "@var-log"];
          "/mnt/btrfs-pool-data" = ["@var-lib" "@stalwart" "@vaultwarden"];
        };
        # Kept beside its private half in nix-secrets so rotation is one commit.
        sshAccess = [
          (lib.removeSuffix "\n" (builtins.readFile "${inputs.sops-secrets}/btrbk-boxy-to-billy.pub"))
        ];
      };

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
