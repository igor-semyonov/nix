{...}: {
  flake.homeModules.dropbox = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.igix.dropbox;
    # dropbox is a buildFHSEnv wrapper whose launcher bind-mounts every
    # top-level directory, /mnt included. If an x-systemd.automount under /mnt
    # completes while bwrap is applying flags to that bind's submounts, bwrap
    # remounts the new filesystem with the flags it snapshotted from the autofs
    # placeholder (relatime over a noatime fs); changing a locked atime flag in
    # a user namespace is EPERM, and the daemon never starts. Resolving the
    # triggers first makes the mount table stable before bwrap reads it.
    settle = pkgs.writeShellScript "dropbox-settle-mounts" ''
      for p in ${lib.escapeShellArgs cfg.settleMounts}; do
        # These are nofail mounts: a disk that is absent or slow must not keep
        # the daemon from starting.
        ${pkgs.coreutils}/bin/timeout 60 \
          ${pkgs.coreutils}/bin/ls -d "$p/." >/dev/null 2>&1 || true
      done
    '';
  in {
    options.igix.dropbox = {
      enable = lib.mkEnableOption "the Dropbox daemon as a user service";

      package = lib.mkPackageOption pkgs "dropbox" {};

      settleMounts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["/mnt/10tb"];
        description = ''
          Automount points to trigger and wait for before starting the daemon,
          so the mount table is settled before bwrap snapshots it. List every
          `x-systemd.automount` mount point under a directory the FHS launcher
          binds — in practice anything under /mnt.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.user.services.dropbox = {
        Unit = {
          Description = "Dropbox";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };

        Install.WantedBy = ["graphical-session.target"];

        Service =
          {
            # The FHS runScript execs dropboxd in the foreground, but the daemon
            # re-execs itself on self-update, so track the cgroup rather than the
            # initial pid.
            Type = "exec";
            ExitType = "cgroup";
            ExecStart = lib.getExe cfg.package;
            Restart = "on-failure";
            RestartSec = 10;
            TimeoutStopSec = "5s";
            Slice = "app.slice";
          }
          // lib.optionalAttrs (cfg.settleMounts != []) {
            ExecStartPre = "${settle}";
          };
      };
    };
  };
}
