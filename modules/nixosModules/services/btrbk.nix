{...}: {
  flake.nixosModules.btrbk = {
    lib,
    config,
    ...
  }: let
    cfg = config.igix.btrbk;
  in {
    options.igix.btrbk = {
      enable = lib.mkEnableOption "Enable BTRBK backing up for main drive";
      snapshots = {
        subvolumes = lib.mkOption {
          type = lib.types.listOf lib.types.singleLineStr;
          description = "List of subvolumes to be snapshotted on main drive";
          default = ["@" "@home"];
        };
        preserve = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "Value for target_preserve";
          default = "48h 14d 8w 5m";
        };
      };
      target = {
        enable = lib.mkEnableOption "Enable backing up to target";
        subvolumes = lib.mkOption {
          type = lib.types.listOf lib.types.singleLineStr;
          description = "List of subvolumes to be backed up to target location";
          default = ["@" "@home"];
        };
        location = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "Target location where to send snapshots";
          default = "/mnt/8tb/btrbk-snapshots/";
        };
        preserve = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "Value for target_preserve";
          default = "10h 14d 8w 5m";
        };
      };
    };

    config = lib.mkIf cfg.enable {
      services.btrbk = {
        instances =
          {
            local_snapshots = {
              onCalendar = "*:0/15";
              settings = {
                timestamp_format = "long";
                preserve_day_of_week = "monday";
                preserve_hour_of_day = "0";
                snapshot_create = "always";
                snapshot_preserve = cfg.snapshots.preserve;
                snapshot_preserve_min = "24h";
                volume = {
                  "/mnt/btrfs-pool" = {
                    snapshot_dir = "btrbk-snapshots";
                    subvolume = lib.genAttrs cfg.snapshots.subvolumes (
                      subvolume: {}
                    );
                  };
                };
              };
            };
          }
          // lib.optionalAttrs
          cfg.target.enable
          {
            local_backup = {
              onCalendar = "0/8:00";
              settings = {
                timestamp_format = "long";
                preserve_day_of_week = "monday";
                preserve_hour_of_day = "0";
                snapshot_create = "no";
                snapshot_preserve = "no";
                target_preserve = cfg.target.preserve;
                target_preserve_min = "no";
                volume = {
                  "/mnt/btrfs-pool" = {
                    snapshot_dir = "btrbk-snapshots";
                    subvolume = lib.genAttrs cfg.target.subvolumes (
                      subvolume: {target = cfg.target.location;}
                    );
                  };
                };
              };
            };
          };
      };
    };
  };
}
