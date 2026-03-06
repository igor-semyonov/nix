{config, ...}: let
  ns = config.namespace-specifier;
in {
  flake.nixosModules.u2f = {
    lib,
    config,
    ...
  }: let
    cfg = config.${ns}.u2f;
  in {
    options.${ns}.u2f = {
      enable = lib.mkEnableOption "Enable u2f login using yubikey for the given users using the specified yubikey";
      keys = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
        default = [
          "b4BNgldsZhyV6AqJe12pB9iQK91y2Cr5BV34v1yl59Qg5UJRxW7bnjQWuOc3Rk5Fgpumo4zSVPdcNoA7OJfgOQ==,GjTum3zXi2oCpA6UsHu2LlgFWn8n4ruV/fV2ZWku5W3QKkWyanjIbW9L6HL5U4ycKaagdwxrvT3Yt4fHaIriWQ==,es256,+presence" # main
          "cohCmzUQUhBfal8rIjBdwRGp62TOhYmEw0OgS/D0XQzeCTxDaii/ftHwlkACXU3c1S17HdmdMFKBf5OYpnuOiw==,0Wbp+SrwTTlOU/2Ogq0tC2oh+emSYNPBcl3QznOyONqXSMDt6AudB0Dzq1uYRDRxj3++PUUeOxIONiAImGmh6g==,es256,+presence" # backup
        ];
        description = "List of the results of running `pamu2fcfg -o pam://<shared-id>` with the leading '<username>:' stripped. for each yubikey";
      };
      sharedId = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "pam://igix";
        description = "The shared id used to generate the u2f keys";
      };
      users = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
        default = ["igor"];
        description = "List of users who will use these keys to sign in.";
      };
      authfile = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "u2f-mappings";
        description = "The global u2f keys/mappings file specified relative to /etc/";
      };
      debug = lib.mkEnableOption "Turn on pam u2f debugging";
    };
    config = lib.mkIf cfg.enable {
      security.pam = {
        u2f = {
          enable = true;
          control = "sufficient";
          settings = {
            cue = true;
            debug = cfg.debug;
            appID = cfg.sharedId;
            origin = cfg.sharedId;
            authfile = "/etc/${cfg.authfile}";
          };
        };
        services.sddm.u2fAuth = false;
      };
      environment.etc.${cfg.authfile} = {
        text =
          lib.strings.join "\n"
          (map (
              user:
                "${user}:"
                + lib.strings.join ":"
                cfg.keys
            )
            cfg.users);
      };
    };
  };
}
