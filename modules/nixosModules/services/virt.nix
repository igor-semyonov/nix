{config, ...}: let
  ns = config.namespace-specifier;
  users = config.users;
in {
  flake.nixosModules.virt = {
    pkgs,
    lib,
    config,
    includedUsers,
    ...
  }: let
    cfg = config.${ns}.virtualisation;
  in {
    options.${ns}.virtualisation = {
      enable = lib.mkEnableOption "Enable virtualisation";
      hardware-interfaces = lib.mkOption {
        default = [];
        description = "The hardware interfaces to add to the bridge to which libvirtd will also be added.";
        type = lib.types.listOf lib.types.str;
      };
      spiceUSBRedirection.enable = lib.mkEnableOption "Enable spice usb redirection";
    };
    config = lib.mkIf cfg.enable {
      users.users = lib.mapAttrs (n: v: {extraGroups = ["kvm" "libvirtd"];}) (lib.filterAttrs (n: v: lib.elem n includedUsers) users);
      virtualisation = {
        libvirtd = {
          enable = true;
          qemu = {
            vhostUserPackages = with pkgs; [virtiofsd];
            swtpm.enable = true;
          };
          allowedBridges = ["br0"];
        };
        spiceUSBRedirection.enable = cfg.spiceUSBRedirection.enable;
      };

      networking = {
        bridges.br0 = {
          interfaces = cfg.hardware-interfaces;
        };
        interfaces =
          {
            br0.useDHCP = true;
          }
          // builtins.listToAttrs (
            map (
              name: {
                name = name;
                value = {useDHCP = true;};
              }
            )
            cfg.hardware-interfaces
          );
      };

      environment.systemPackages = with pkgs; [
        dnsmasq
        OVMFFull
      ];
    };
  };
}
