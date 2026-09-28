{...}: {
  flake.nixosModules.media-jellyfin = {
    config,
    lib,
    ...
  }: let
    cfg = config.igix.jellyfin;

    # Kept byte-identical to the same rules in media-ripping.nix so that the two
    # modules merge instead of conflicting when both are enabled.
    libraryDirs = [cfg.libraryRoot "${cfg.libraryRoot}/movies" "${cfg.libraryRoot}/tv"];
  in {
    options.igix.jellyfin = {
      enable = lib.mkEnableOption "Jellyfin media server";

      libraryRoot = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/8tb/@media";
        description = ''
          Root of the media tree. `movies` and `tv` below it are created and are
          the paths to point Jellyfin's libraries at.
        '';
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "media";
        description = "Group owning the media tree; Jellyfin joins it to read the library.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open the Jellyfin HTTP and discovery ports.";
      };

      nvenc = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use NVENC/NVDEC for on-the-fly transcoding.";
        };

        device = lib.mkOption {
          type = lib.types.str;
          default = "/dev/nvidia0";
          description = "Render node passed to Jellyfin as the acceleration device.";
        };

        av1 = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Allow AV1 as a transcode *output* codec. Requires an Ada (SM 8.9) or
            newer GPU; older cards must leave this off and fall back to HEVC.
          '';
        };
      };
    };

    config = lib.mkIf cfg.enable {
      users.groups.${cfg.group} = {};
      users.users.jellyfin.extraGroups = [cfg.group];

      systemd.tmpfiles.settings.igix-media = lib.genAttrs libraryDirs (_: {
        d = {
          mode = "2775";
          user = "root";
          inherit (cfg) group;
        };
      });

      services.jellyfin = {
        enable = true;
        inherit (cfg) openFirewall;
        # NixOS owns encoding.xml; changing transcode settings in the web UI
        # would otherwise silently survive and diverge from this module.
        forceEncodingConfig = true;

        hardwareAcceleration = lib.mkIf cfg.nvenc.enable {
          enable = true;
          type = "nvenc";
          inherit (cfg.nvenc) device;
        };

        transcoding = {
          enableHardwareEncoding = cfg.nvenc.enable;
          # h264 is not listed because Jellyfin always uses the hardware h264
          # encoder once enableHardwareEncoding is set; these two are the
          # opt-in extras.
          hardwareEncodingCodecs = {
            hevc = cfg.nvenc.enable;
            av1 = cfg.nvenc.enable && cfg.nvenc.av1;
          };
          hardwareDecodingCodecs = {
            h264 = cfg.nvenc.enable;
            hevc = cfg.nvenc.enable;
            mpeg2 = cfg.nvenc.enable;
            vc1 = cfg.nvenc.enable;
            vp8 = cfg.nvenc.enable;
            vp9 = cfg.nvenc.enable;
            av1 = cfg.nvenc.enable;
            hevc10bit = cfg.nvenc.enable;
          };
          # The library is 10-bit AV1; clients that cannot take HDR need the
          # CUDA tonemap filter rather than a software fallback.
          enableToneMapping = true;
          enableSubtitleExtraction = true;
          throttleTranscoding = true;
        };
      };

      systemd.services.jellyfin = {
        unitConfig.RequiresMountsFor = [cfg.libraryRoot];
        serviceConfig = lib.mkIf cfg.nvenc.enable {
          # The upstream module only allows hardwareAcceleration.device; NVENC
          # additionally opens the control and UVM nodes. unitOption merges
          # lists, so these append to the upstream entry.
          DeviceAllow = [
            "/dev/nvidiactl rw"
            "/dev/nvidia-uvm rw"
            "/dev/nvidia-uvm-tools rw"
            "/dev/nvidia-modeset rw"
          ];
          SupplementaryGroups = ["video" "render"];
        };
      };
    };
  };
}
