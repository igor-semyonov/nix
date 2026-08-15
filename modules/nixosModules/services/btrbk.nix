{...}: {
  flake.nixosModules.btrbk = {
    lib,
    config,
    ...
  }: let
    cfg = config.igix.btrbk;

    snapshotDir = "btrbk-snapshots";

    # attrsOf (listOf str) -> btrbk `volume` settings block.
    mkVolumes = f:
      lib.mapAttrs (_volume: subvolumes: {
        snapshot_dir = snapshotDir;
        subvolume = lib.genAttrs subvolumes f;
      });

    targetVolumes =
      if cfg.target.volumes == {}
      then cfg.snapshots.volumes
      else cfg.target.volumes;

    # Each remote pool receives into its own subdirectory, so subvolumes
    # sharing a name across pools cannot collide in the target.
    pullTargetDir = pull: volume: "${pull.target}/${lib.replaceStrings ["/"] ["-"] (lib.removePrefix "/" volume)}";

    pullInstances = lib.mapAttrs' (name: pull:
      lib.nameValuePair "pull_${name}" {
        inherit (pull) onCalendar;
        settings = {
          timestamp_format = "long";
          preserve_day_of_week = "monday";
          preserve_hour_of_day = "0";
          ssh_user = pull.sshUser;
          ssh_identity = pull.sshIdentity;
          stream_compress = "zstd";
          # Snapshots are created by the source host's own instance.
          snapshot_create = "no";
          snapshot_preserve = "no";
          target_preserve = pull.preserve;
          target_preserve_min = "no";
          volume = lib.mapAttrs' (volume: subvolumes:
            lib.nameValuePair "ssh://${pull.host}${volume}" {
              snapshot_dir = snapshotDir;
              subvolume = lib.genAttrs subvolumes (_: {
                target = pullTargetDir pull volume;
              });
            })
          pull.volumes;
        };
      })
    cfg.pull;
  in {
    options.igix.btrbk = {
      enable = lib.mkEnableOption "Enable BTRBK snapshotting";
      snapshots = {
        volumes = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.singleLineStr);
          description = "Btrfs pool mountpoint -> subvolumes to snapshot.";
          default = {"/mnt/btrfs-pool" = ["@" "@home"];};
        };
        preserve = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "Value for snapshot_preserve";
          default = "48h 14d 8w 5m";
        };
        onCalendar = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "How often to snapshot";
          default = "*:0/15";
        };
      };
      target = {
        enable = lib.mkEnableOption "Enable backing up to a local target";
        volumes = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.singleLineStr);
          description = "Pool -> subvolumes to back up. Empty means reuse snapshots.volumes.";
          default = {};
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
      sshAccess = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
        description = "Public keys permitted to pull snapshots from this host.";
        default = [];
      };
      sshAccessRoles = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
        description = "ssh_filter_btrbk roles granted to sshAccess keys.";
        default = ["info" "source" "send"];
      };
      pull = lib.mkOption {
        description = "Pull snapshots from remote hosts into a local target.";
        default = {};
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.singleLineStr;
              description = "Remote host to pull from.";
            };
            volumes = lib.mkOption {
              type = lib.types.attrsOf (lib.types.listOf lib.types.singleLineStr);
              description = "Remote pool mountpoint -> subvolumes to pull.";
            };
            target = lib.mkOption {
              type = lib.types.singleLineStr;
              description = "Local directory to receive into.";
            };
            preserve = lib.mkOption {
              type = lib.types.singleLineStr;
              description = "Value for target_preserve";
              default = "10h 14d 8w 12m";
            };
            sshUser = lib.mkOption {
              type = lib.types.singleLineStr;
              description = "Remote user, as created by services.btrbk.sshAccess.";
              default = "btrbk";
            };
            sshIdentity = lib.mkOption {
              type = lib.types.singleLineStr;
              description = "Path to the private key readable by the btrbk user.";
            };
            onCalendar = lib.mkOption {
              type = lib.types.singleLineStr;
              description = "How often to pull";
              default = "0/4:00";
            };
          };
        });
      };
    };

    config = lib.mkMerge [
      (lib.mkIf (cfg.sshAccess != []) {
        services.btrbk.sshAccess =
          map (key: {
            inherit key;
            roles = cfg.sshAccessRoles;
          })
          cfg.sshAccess;
      })

      (lib.mkIf (cfg.pull != {}) {
        services.btrbk.instances = pullInstances;
        systemd.tmpfiles.rules = lib.concatLists (lib.mapAttrsToList (_: pull:
          ["d ${pull.target} 0750 btrbk btrbk - -"]
          ++ lib.mapAttrsToList
          (volume: _: "d ${pullTargetDir pull volume} 0750 btrbk btrbk - -")
          pull.volumes)
        cfg.pull);
      })

      (lib.mkIf cfg.enable {
        # btrbk requires snapshot_dir to exist; it will not create it.
        systemd.tmpfiles.rules =
          lib.mapAttrsToList (volume: _: "d ${volume}/${snapshotDir} 0750 root btrbk - -")
          cfg.snapshots.volumes;

        services.btrbk.instances =
          {
            local_snapshots = {
              inherit (cfg.snapshots) onCalendar;
              settings = {
                timestamp_format = "long";
                preserve_day_of_week = "monday";
                preserve_hour_of_day = "0";
                snapshot_create = "always";
                snapshot_preserve = cfg.snapshots.preserve;
                snapshot_preserve_min = "24h";
                volume = mkVolumes (_: {}) cfg.snapshots.volumes;
              };
            };
          }
          // lib.optionalAttrs cfg.target.enable {
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
                volume = mkVolumes (_: {target = cfg.target.location;}) targetVolumes;
              };
            };
          };
      })
    ];
  };
}
