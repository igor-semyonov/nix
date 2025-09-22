{
  pkgs,
  lib,
  userConfig,
  config,
  ...
}: let
  cfg = config.mine.nas;
in {
  options.mine.nas = {
    enable = lib.mkEnableOption "Enable NAS mounts";
    host = lib.mkOption {
      default = "synology.local";
      description = "Base addresso f my NAS";
      type = lib.types.string;
    };
    shares = lib.mkOption {
      default = [
        "share-1"
      ];
      description = "Which shares to mount";
      type = lib.types.listOf lib.types.string;
    };
    mount-root = lib.mkOption {
      default = "/mnt/nas";
      description = "Each share will be mounted as a subdirectory of this path.";
      type = lib.types.string;
    };
    credentialsFile = lib.mkOption {
      default = "/root/secrets/syn.credentials";
      description = "Path to credentials file";
      type = lib.types.string;
    };
    extraMountOptions = lib.mkOption {
      default = [
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=10s"
      ];
      description = "Mount options in addition to credentials, uid, and gid";
      type = lib.types.listOf lib.types.string;
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.cifs-utils];

    fileSystems = builtins.listToAttrs (map (share: {
        name = "${cfg.mount-root}/${share}";
        value = {
          device = "//${cfg.host}/${share}";
          fsType = "cifs";
          options =
            [
              "credentials=${cfg.credentialsFile}"
              "uid=${userConfig.name}"
              "gid=wheel"
            ]
            ++ cfg.extraMountOptions;
          noCheck = true;
        };
      })
      cfg.shares);
  };
}
