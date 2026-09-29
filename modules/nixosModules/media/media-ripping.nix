{...}: {
  flake.nixosModules.media-ripping = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.igix.media-ripping;

    # Byte-identical to the same rules in jellyfin.nix so the two modules merge
    # rather than conflict when both are enabled.
    libraryDirs = [cfg.libraryRoot "${cfg.libraryRoot}/movies" "${cfg.libraryRoot}/tv"];

    orEmpty = p:
      if p == null
      then ""
      else toString p;

    pathEnv = {
      MEDIA_LIBRARY_ROOT = cfg.libraryRoot;
      MEDIA_RIP_DIR = cfg.ripDir;
      MEDIA_TRANSCODE_DIR = cfg.transcodeDir;
      MEDIA_STATE_DIR = cfg.stateDir;
    };

    # One scan pass shared by every front end and the worker, so disc parsing
    # has a single definition.
    discScan = pkgs.writeShellApplication {
      name = "media-disc-scan";
      runtimeInputs = with pkgs; [gawk makemkv];
      text = builtins.readFile ./media-disc-scan.sh;
    };

    waitForDisc = pkgs.writeShellApplication {
      name = "media-wait-for-disc";
      runtimeInputs = [pkgs.coreutils];
      text = builtins.readFile ./media-wait-for-disc.sh;
    };

    guessTitles = pkgs.writeShellApplication {
      name = "media-guess-titles";
      runtimeInputs = [pkgs.gawk];
      runtimeEnv.MEDIA_EPISODE_TOLERANCE = toString cfg.episodeTolerance;
      text = builtins.readFile ./media-guess-titles.sh;
    };

    # Single definition of the library naming scheme, so the destination
    # rip-tv shows for confirmation is the one the worker writes.
    libraryPath = pkgs.writeShellApplication {
      name = "media-library-path";
      runtimeInputs = with pkgs; [coreutils gnused];
      runtimeEnv.MEDIA_LIBRARY_ROOT = cfg.libraryRoot;
      text = builtins.readFile ./media-library-path.sh;
    };

    pickTitles = pkgs.writeShellApplication {
      name = "media-pick-titles";
      runtimeInputs = [libraryPath] ++ (with pkgs; [coreutils gawk gnugrep]);
      text = builtins.readFile ./media-pick-titles.sh;
    };

    # Installed for the user as well as used by the worker: an expired build is
    # the failure mode you want to be able to check for before loading a disc.
    makemkvCheck = pkgs.writeShellApplication {
      name = "makemkv-status";
      runtimeInputs = with pkgs; [coreutils gnugrep gnused makemkv];
      runtimeEnv = {
        MAKEMKV_KEY_FILE = orEmpty cfg.makemkvKeyFile;
        # So the remediation it prints names the service account, not whoever
        # happened to run the check.
        MEDIA_RIP_USER = cfg.user;
        MEDIA_RIP_GROUP = cfg.group;
      };
      text = builtins.readFile ./media-makemkv-check.sh;
    };

    helpers = [discScan waitForDisc guessTitles pickTitles libraryPath];

    cliEnv =
      pathEnv
      // {
        MEDIA_DEFAULT_DEVICE = cfg.device;
        MEDIA_MIN_LENGTH = toString cfg.minLengthSeconds;
        MEDIA_TV_MIN_LENGTH = toString cfg.tvMinLengthSeconds;
        MEDIA_EPISODE_TOLERANCE = toString cfg.episodeTolerance;
        MEDIA_WAIT = toString cfg.waitForDiscSeconds;
        MEDIA_EJECT = lib.boolToString cfg.eject;
      };

    mkCli = name: source:
      pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = helpers ++ (with pkgs; [coreutils gawk jq]);
        runtimeEnv = cliEnv;
        text = builtins.readFile source;
      };

    ripMovie = mkCli "rip-movie" ./rip-movie.sh;
    ripTv = mkCli "rip-tv" ./rip-tv.sh;
    ripTitles = mkCli "rip-titles" ./rip-titles.sh;

    ripWorker = pkgs.writeShellApplication {
      name = "media-rip-worker";
      runtimeInputs = helpers ++ [makemkvCheck] ++ (with pkgs; [coreutils gawk gnused jq makemkv util-linux]);
      runtimeEnv = pathEnv // {MAKEMKV_KEY_FILE = orEmpty cfg.makemkvKeyFile;};
      text = builtins.readFile ./media-rip-worker.sh;
    };

    encodeWorker = pkgs.writeShellApplication {
      name = "media-encode-worker";
      runtimeInputs = [cfg.ffmpeg] ++ (with pkgs; [coreutils curl gawk jq]);
      runtimeEnv =
        pathEnv
        // {
          MEDIA_PRESET = toString cfg.encode.preset;
          MEDIA_CRF = toString cfg.encode.crf;
          MEDIA_PIX_FMT = cfg.encode.pixelFormat;
          MEDIA_KEYINT = toString cfg.encode.keyframeInterval;
          MEDIA_FILM_GRAIN = toString cfg.encode.filmGrain;
          MEDIA_SVT_TUNE = toString cfg.encode.tune;
          MEDIA_SVT_EXTRA = cfg.encode.extraSvtParams;
          MEDIA_AUDIO = cfg.encode.audio;
          MEDIA_OPUS_BITRATE = cfg.encode.opusBitrate;
          MEDIA_KEEP_RIPS = lib.boolToString cfg.encode.keepRips;
          MEDIA_JELLYFIN_URL = cfg.jellyfin.url;
          MEDIA_JELLYFIN_API_KEY_FILE = orEmpty cfg.jellyfin.apiKeyFile;
        };
      text = builtins.readFile ./media-encode-worker.sh;
    };

    # Both workers write into the library and the staging area under an
    # automounted disk, and neither may be killed part-way through.
    workerService = {
      after = ["network.target"];
      unitConfig.RequiresMountsFor = [cfg.libraryRoot cfg.ripDir cfg.transcodeDir];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        Environment = ["HOME=${cfg.stateDir}"];
        # setgid library directories plus a group-writable umask is what lets
        # Jellyfin read everything without depending on file ownership.
        UMask = "0002";
        TimeoutStartSec = "infinity";
        Nice = 10;
        IOSchedulingClass = "idle";
        CPUWeight = 20;
      };
    };
  in {
    options.igix.media-ripping = {
      enable = lib.mkEnableOption "Blu-ray/DVD ripping and AV1 encoding pipeline";

      libraryRoot = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/8tb/@media";
        description = "Media library root; finished encodes land in `movies` and `tv` below it.";
      };

      ripDir = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/8tb/media-rips";
        description = ''
          Staging directory MakeMKV rips into. Holds full-size lossless titles
          (30-60 GiB each), so it must be on the big disk, not on `/`.
        '';
      };

      transcodeDir = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/8tb/@media/.transcoding";
        description = ''
          Where in-progress AV1 encodes are written. Must be on the same
          filesystem *and* btrfs subvolume as {option}`libraryRoot`, otherwise
          the final move is a copy instead of a rename.
        '';
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/media-ripping";
        description = "Holds the rip-request and encode-job queues and the MakeMKV key.";
      };

      device = lib.mkOption {
        type = lib.types.str;
        default = "/dev/sr0";
        description = "Default optical device for `media-rip`.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "media-rip";
        description = "System account the rip and encode workers run as.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "media";
        description = "Group owning the media tree; must match {option}`igix.jellyfin.group`.";
      };

      allowedUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["igor"];
        description = "Users allowed to queue rips and read the library.";
      };

      minLengthSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 900;
        description = ''
          Floor for `rip-movie`. Titles shorter than this are ignored, which
          discards the playlist obfuscation decoys and studio idents most
          feature discs carry.
        '';
      };

      tvMinLengthSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 600;
        description = ''
          Floor for `rip-tv` and `rip-titles`. Lower than the movie floor
          because a half-hour show's episodes run ~22 minutes and the median
          clustering, not the floor, is what rejects the featurettes.
        '';
      };

      episodeTolerance = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 25;
        description = ''
          Half-width, in percent, of the window around the median title length
          that `rip-tv` treats as an episode. Excludes the "play all" title and
          the extras; widen it for a disc mixing single and double-length
          episodes.
        '';
      };

      waitForDiscSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 300;
        description = ''
          How long the worker waits for a readable disc before failing a
          request, so `rip-tv` can be queued before the disc goes in.
        '';
      };

      eject = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Eject the disc once ripping finishes. Also re-arms the auto-rip latch.";
      };

      makemkvKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/var/lib/media-ripping/makemkv.key";
        description = ''
          File containing the MakeMKV registration key, installed into the
          worker's `settings.conf` on each run. The free beta key expires every
          couple of months and has to be replaced by hand.
        '';
      };

      installGui = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the MakeMKV GUI for discs the automatic title picker gets wrong.";
      };

      autoRip = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Start a movie rip automatically when a Blu-ray or DVD is inserted,
            naming it from the disc label.
          '';
        };

        devices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["sr[0-9]*"];
          description = "udev KERNEL patterns of drives that trigger an automatic rip.";
        };

        graceSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 60;
          description = ''
            How long the automatic rip pauses after a disc is inserted before
            claiming it, leaving time to run `rip-tv` instead. Costs nothing:
            the rip that follows takes hours.
          '';
        };
      };

      ffmpeg = lib.mkPackageOption pkgs "ffmpeg-headless" {};

      encode = {
        preset = lib.mkOption {
          type = lib.types.ints.between (-1) 13;
          default = 3;
          description = "SVT-AV1 preset. Lower is slower and smaller; 3-4 is archival quality.";
        };

        crf = lib.mkOption {
          type = lib.types.ints.between 1 63;
          default = 22;
          description = "SVT-AV1 CRF. ~22 is visually transparent for 1080p Blu-ray at preset 3.";
        };

        pixelFormat = lib.mkOption {
          type = lib.types.str;
          default = "yuv420p10le";
          description = ''
            10-bit even for 8-bit sources: AV1's 10-bit path costs almost
            nothing and avoids the banding 8-bit encoding introduces.
          '';
        };

        keyframeInterval = lib.mkOption {
          type = lib.types.ints.positive;
          default = 240;
          description = "Maximum GOP length in frames; 240 is ~10s at 24fps.";
        };

        filmGrain = lib.mkOption {
          type = lib.types.ints.between 0 50;
          default = 8;
          description = ''
            AV1 film grain synthesis level. Restores the grain low CRFs smear
            away on film transfers; set 0 for animation.
          '';
        };

        tune = lib.mkOption {
          type = lib.types.ints.between 0 4;
          default = 0;
          description = "SVT-AV1 tune: 0 VQ, 1 PSNR, 2 SSIM, 3 IQ, 4 MS-SSIM.";
        };

        extraSvtParams = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "lp=16";
          description = "Extra colon-separated `-svtav1-params` appended to the defaults.";
        };

        audio = lib.mkOption {
          type = lib.types.enum ["copy" "opus"];
          default = "copy";
          description = ''
            `copy` keeps the disc's lossless TrueHD/DTS-HD track, worth several
            GiB per film; `opus` re-encodes it.
          '';
        };

        opusBitrate = lib.mkOption {
          type = lib.types.str;
          default = "256k";
          description = "Target bitrate when {option}`audio` is `opus`.";
        };

        keepRips = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Keep the lossless MakeMKV rip after a successful encode.";
        };
      };

      jellyfin = {
        url = lib.mkOption {
          type = lib.types.str;
          default = "http://localhost:8096";
          description = "Jellyfin base URL used for the post-encode library refresh.";
        };

        apiKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            API key for the post-encode library refresh. Optional: Jellyfin's
            real-time monitoring picks new files up on its own, this only makes
            it immediate.
          '';
        };
      };
    };

    config = lib.mkIf cfg.enable {
      # MakeMKV talks to the drive through SCSI generic, not the block device:
      # AACS handshakes and LibreDrive both need raw command passthrough. sg is
      # a module here and nothing else requests char-major-21, so without this
      # /dev/sg* never appears and makemkvcon reports "no usable optical
      # drives" even though /dev/sr0 works fine.
      boot.kernelModules = ["sg"];

      users.groups.${cfg.group} = {};

      users.users = lib.mkMerge [
        {
          ${cfg.user} = {
            isSystemUser = true;
            inherit (cfg) group;
            extraGroups = ["cdrom"];
            home = cfg.stateDir;
            createHome = false;
            description = "Blu-ray ripping and AV1 encoding";
          };
        }
        (lib.genAttrs cfg.allowedUsers (_: {
          extraGroups = [cfg.group "cdrom"];
        }))
      ];

      environment.systemPackages =
        [ripMovie ripTv ripTitles makemkvCheck]
        ++ lib.optional cfg.installGui pkgs.makemkv;

      systemd.tmpfiles.settings = {
        igix-media = lib.genAttrs libraryDirs (_: {
          d = {
            mode = "2775";
            user = "root";
            inherit (cfg) group;
          };
        });

        igix-media-ripping =
          lib.genAttrs [cfg.ripDir cfg.transcodeDir cfg.stateDir "${cfg.stateDir}/encode-queue"] (_: {
            d = {
              mode = "0775";
              inherit (cfg) user group;
            };
          })
          // lib.genAttrs [
            # setgid and group-writable so rip-movie/rip-tv can queue and claim
            # the drive unprivileged.
            "${cfg.stateDir}/rip-queue"
            "${cfg.stateDir}/claims"
          ] (_: {
            d = {
              mode = "2775";
              inherit (cfg) user group;
            };
          });
      };

      systemd.paths = {
        media-rip = {
          description = "Watch for Blu-ray rip requests";
          wantedBy = ["multi-user.target"];
          pathConfig.PathExistsGlob = "${cfg.stateDir}/rip-queue/*.json";
        };
        media-encode = {
          description = "Watch for queued AV1 encodes";
          wantedBy = ["multi-user.target"];
          pathConfig.PathExistsGlob = "${cfg.stateDir}/encode-queue/*.json";
        };
      };

      systemd.services = {
        # A path unit will not retrigger while its service runs, which is what
        # keeps rips (contending for the drive) and encodes (for the CPU)
        # strictly serial. Each run drains everything queued at start.
        media-rip = lib.recursiveUpdate workerService {
          description = "Rip queued discs with MakeMKV";
          serviceConfig.ExecStart = lib.getExe ripWorker;
        };

        media-encode = lib.recursiveUpdate workerService {
          description = "Encode ripped titles to AV1";
          serviceConfig.ExecStart = lib.getExe encodeWorker;
        };

        "media-autorip@" = lib.mkIf cfg.autoRip.enable {
          description = "Queue an automatic rip for /dev/%I";
          # Latched: udev emits several `change` events per disc and a started
          # oneshot with RemainAfterExit will not re-run. Media removal stops
          # the instance, re-arming it for the next disc.
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # The pause is what makes the claim winnable: inserting a TV disc
            # and then reaching for rip-tv has to beat this to the drive.
            ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString cfg.autoRip.graceSeconds}";
            # --if-unclaimed also stands down if a request for this drive is
            # already queued.
            ExecStart = "${lib.getExe ripMovie} --if-unclaimed --device /dev/%I";
          };
        };
      };

      services.udev.extraRules = lib.mkIf cfg.autoRip.enable (
        lib.concatMapStringsSep "\n" (kernel: ''
          SUBSYSTEM=="block", KERNEL=="${kernel}", ACTION=="change", ENV{ID_CDROM_MEDIA_STATE}!="blank", ENV{ID_CDROM_MEDIA_BD}=="1", ENV{SYSTEMD_WANTS}+="media-autorip@%k.service"
          SUBSYSTEM=="block", KERNEL=="${kernel}", ACTION=="change", ENV{ID_CDROM_MEDIA_STATE}!="blank", ENV{ID_CDROM_MEDIA_DVD}=="1", ENV{SYSTEMD_WANTS}+="media-autorip@%k.service"
          SUBSYSTEM=="block", KERNEL=="${kernel}", ACTION=="change", ENV{ID_CDROM_MEDIA}!="1", RUN+="${config.systemd.package}/bin/systemctl --no-block stop media-autorip@%k.service"
        '')
        cfg.autoRip.devices
      );
    };
  };
}
