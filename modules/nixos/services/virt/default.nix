{
  pkgs,
  lib,
  config,
  userConfig,
  ...
}: let
  cfg = config.mine.virtualisation;
in {
  options.mine.virtualisation = {
    enable = lib.mkEnableOption "Enable virtualisation";
    hardware-interfaces = lib.mkOption {
      default = [];
      description = "The hardware interfaces to add to the bridge to which libvirtd will also be added.";
      type = lib.types.listOf lib.types.str;
    };
    spiceUSBRedirection.enable = lib.mkEnableOption "Enable spice usb redirection";
  };
  config = lib.mkIf cfg.enable {
    users.users.${userConfig.name}.extraGroups = ["kvm" "libvirtd"];
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
}
