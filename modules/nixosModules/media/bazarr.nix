{...}: {
  flake.nixosModules.media-bazarr = {
    config,
    lib,
    ...
  }: let
    cfg = config.igix.bazarr;
  in {
    options.igix.bazarr = {
      enable = lib.mkEnableOption ''
        Bazarr subtitle manager. Replaces Jellyfin's OpenSubtitles plugin: it
        owns provider credentials, language rules and retry/quota handling
        itself, and writes .srt sidecars next to the media, which Jellyfin
        picks up as external subtitles with no plugin involved
      '';

      group = lib.mkOption {
        type = lib.types.str;
        default = "media";
        description = ''
          Group owning the media tree. Bazarr runs under it so it can write
          sidecars; must match {option}`igix.jellyfin.group`.
        '';
      };

      libraryRoot = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/8tb/@media";
        description = "Media root Bazarr is pointed at when adding paths in its UI.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open Bazarr's web UI port on the LAN.";
      };
    };

    config = lib.mkIf cfg.enable {
      users.groups.${cfg.group} = {};

      services.bazarr = {
        enable = true;
        # Runs as its own user but in the media group, so sidecars land
        # group-writable alongside files the encoder wrote.
        inherit (cfg) group openFirewall;
      };

      # Sidecars must be readable by jellyfin, which is also in this group;
      # the default 0022 would make them group-read-only by luck rather than
      # by intent, and Bazarr also rewrites them when syncing.
      systemd.services.bazarr = {
        serviceConfig.UMask = "0002";
        unitConfig.RequiresMountsFor = [cfg.libraryRoot];
      };
    };
  };
}
