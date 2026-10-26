{...}: {
  flake.nixosModules.vaultwarden = {
    config,
    lib,
    ...
  }: let
    cfg = config.igix.vaultwarden;
  in {
    options.igix.vaultwarden = {
      enable = lib.mkEnableOption "Vaultwarden on the SQLite backend";

      domain = lib.mkOption {
        type = lib.types.singleLineStr;
        description = ''
          Full origin clients reach, scheme and any non-default port included.
          WebAuthn derives its Relying Party ID from the host part, so every
          registered FIDO2 key and passkey is cryptographically scoped to this
          value -- changing it silently invalidates all of them.
        '';
        example = "https://vault.nalgor.net";
      };

      address = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "127.0.0.1";
        description = "Address Rocket binds. Keep it loopback behind a reverse proxy.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8222;
        description = "Port Rocket binds.";
      };

      signupsAllowed = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow self-registration. Off means accounts arrive only by invitation.";
      };

      backupDir = lib.mkOption {
        type = lib.types.nullOr lib.types.singleLineStr;
        default = null;
        description = ''
          Where the bundled timer writes a `sqlite3 .backup` copy; must be outside
          the data dir. That consistent copy is what a snapshotter should pick up,
          since snapshotting the live WAL database is not equivalent.
        '';
        example = "/var/lib/vaultwarden-backup";
      };

      environmentFile = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [];
        description = "Extra env files, for secrets such as ADMIN_TOKEN and SMTP_PASSWORD.";
      };
    };

    config = lib.mkIf cfg.enable {
      services.vaultwarden = {
        enable = true;
        dbBackend = "sqlite";
        inherit (cfg) backupDir environmentFile;
        config = {
          DOMAIN = cfg.domain;
          ROCKET_ADDRESS = cfg.address;
          ROCKET_PORT = cfg.port;
          SIGNUPS_ALLOWED = cfg.signupsAllowed;
        };
      };
    };
  };
}
