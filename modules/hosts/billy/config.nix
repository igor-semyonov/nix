{
  buildNixosAndHomeManager,
  inputs,
  self,
  config,
  lib,
  ...
}: let
  ns = config.namespace-specifier;
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

    (
      {config, ...}: {
        users.users = {
          # igor-headless.hashedPasswordFile = config.sops.secrets.igor-pw.path;
          root.openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH5gmBdZsP86dXIL7P/Wb+mBtXO/1xqqKMNKKqLr8SJZ igor@boxy"];
        };

        nix.settings = {
          download-buffer-size = 2 * 1024 * 1024 * 1024;
          cores = 2;
          max-jobs = 2;
        };

        boot.loader = {
          efi = {
            canTouchEfiVariables = true;
            # efiSysMountPoint = "/boot/efi"; #  defaults to /boot
          };
          timeout = 5;
          systemd-boot = {
            enable = true;
            memtest86.enable = false;
            configurationLimit = 8;
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
            matchConfig.Name = "ens3";
            networkConfig = {
              DHCP = "ipv4";
              IPv6AcceptRA = false;
            };

            address = ["2604:2dc0:121::6c9/64"];
            routes = [{Gateway = "2604:2dc0:121::1";}];
          };
        };

        ${ns} = {
          btrbk.enable = true;
        };

        system.stateVersion = "26.11";
      }
    )
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
