{inputs, ...}: {
  flake.nixosModules.frigate = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.igix.frigate;

    # With cudaSupport set, Frigate's ML closure (opencv, onnxruntime,
    # tensorflow, jax, triton, magma, ...) becomes CUDA variants that
    # cache.nixos.org never builds; compiling them locally under boxy's job
    # limits exhausted memory. NVENC/NVDEC need none of it, since ffmpeg reaches
    # the GPU through the driver at runtime.
    pkgsNoCuda = import inputs.nixpkgs {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.cudaSupport = false;
    };

    # Where the nixpkgs package expects them; nginx serves /recordings/ from here.
    recordingsMount = "/var/lib/frigate/recordings";
    cacheDir = "/var/cache/frigate";

    restream = name: "rtsp://127.0.0.1:8554/${name}";

    retention = {
      pre_capture = cfg.preCapture;
      post_capture = cfg.postCapture;
      # The default, "motion", discards every segment of the post_capture tail
      # that has no motion in it, so the tail would never actually be kept.
      retain = {
        days = cfg.retainDays;
        mode = "all";
      };
    };
  in {
    options.igix.frigate = {
      enable = lib.mkEnableOption "Frigate NVR behind a loopback-only go2rtc restream";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgsNoCuda.frigate;
        defaultText = lib.literalMD "`frigate` from nixpkgs with `cudaSupport = false`";
        description = ''
          Frigate package. The default comes from a cudaSupport-free nixpkgs so
          its ML dependencies are substituted instead of built as CUDA variants.
        '';
      };

      nvidia = lib.mkEnableOption ''
        NVIDIA video hardware: NVDEC for the detect stream, NVENC for the
        live-view H.264 restream, previews, birdseye and exports. Object
        detection stays on the CPU, as GPU inference needs CUDA onnxruntime
      '';

      hostname = lib.mkOption {
        type = lib.types.singleLineStr;
        default = config.networking.hostName;
        defaultText = lib.literalExpression "config.networking.hostName";
        description = "nginx vhost name for the Frigate UI.";
      };

      firewallInterfaces = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
        default = [];
        example = ["br0"];
        description = ''
          Interfaces on which TCP 80 is opened for the Frigate UI. Per interface
          rather than global so tunnels to other hosts stay closed. Frigate's
          own login guards it.
        '';
      };

      recordingsDir = lib.mkOption {
        type = lib.types.singleLineStr;
        example = "/mnt/8tb/@cameras/recordings";
        description = ''
          Host directory bind-mounted over Frigate's recordings directory.
          Frigate refuses to start if the bind is missing, rather than filling
          the root filesystem underneath it.
        '';
      };

      retainDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 7;
        description = "Days to keep motion segments, review items and snapshots.";
      };

      preCapture = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 5;
        description = "Seconds kept before an alert or detection starts.";
      };

      postCapture = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
        description = "Seconds kept after an alert or detection ends.";
      };

      cacheSize = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "${toString (2 * 1024 * 1024)}K";
        description = ''
          tmpfs size for Frigate's segment cache. Every segment from every
          record stream is written here before Frigate keeps or drops it, so on
          disk this is the full continuous bitrate regardless of retention.
        '';
      };

      cameras = lib.mkOption {
        description = "RTSP cameras, each restreamed once through go2rtc.";
        default = {};
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.singleLineStr;
              example = "10.10.70.12";
              description = "Camera address.";
            };

            username = lib.mkOption {
              type = lib.types.singleLineStr;
              default = "admin";
              description = "RTSP username.";
            };

            passwordFile = lib.mkOption {
              type = lib.types.path;
              description = ''
                File holding the RTSP password, **percent-encoded**. go2rtc
                substitutes it into the URL before parsing its YAML, so the
                encoded form is the one that is safe in both contexts.
              '';
            };

            mainPath = lib.mkOption {
              type = lib.types.singleLineStr;
              default = "h264Preview_01_main";
              description = "RTSP path of the high-resolution stream, used for recording.";
            };

            subPath = lib.mkOption {
              type = lib.types.singleLineStr;
              default = "h264Preview_01_sub";
              description = "RTSP path of the low-resolution stream, used for detection.";
            };

            detect = {
              width = lib.mkOption {
                type = lib.types.ints.positive;
                description = "Sub-stream width; must match what the camera sends.";
              };
              height = lib.mkOption {
                type = lib.types.ints.positive;
                description = "Sub-stream height; must match what the camera sends.";
              };
              fps = lib.mkOption {
                type = lib.types.ints.positive;
                default = 5;
                description = "Detection frame rate.";
              };
            };
          };
        });
      };
    };

    config = lib.mkIf cfg.enable {
      fileSystems = {
        ${recordingsMount} = {
          device = cfg.recordingsDir;
          fsType = "none";
          options = ["bind" "nofail"];
        };
        ${cacheDir} = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = ["size=${cfg.cacheSize}" "mode=0750" "nosuid" "nodev" "noexec"];
        };
      };

      systemd.tmpfiles.settings."10-frigate-recordings".${cfg.recordingsDir}.d = {
        user = "frigate";
        group = "frigate";
        mode = "0750";
      };

      networking.firewall.interfaces = lib.genAttrs cfg.firewallInterfaces (_: {
        allowedTCPPorts = [80];
      });

      services.go2rtc = {
        enable = true;
        settings = {
          # Both default to every interface with no authentication, which would
          # hand the camera feed to anyone who can reach this host.
          api.listen = "127.0.0.1:1984";
          rtsp.listen = "127.0.0.1:8554";
          webrtc.listen = "127.0.0.1:8555";
          streams = lib.concatMapAttrs (name: cam: let
            # go2rtc resolves ${...} from $CREDENTIALS_DIRECTORY and masks the
            # value in its logs and API responses.
            url = path: "rtsp://${cam.username}:\${${name}_password}@${cam.host}:554/${path}";
          in
            {
              ${name} = url cam.mainPath;
              "${name}_sub" = url cam.subPath;
            }
            // lib.optionalAttrs cfg.nvidia {
              # Browsers rarely decode HEVC. go2rtc runs this NVENC transcode
              # only while a client is watching it.
              "${name}_h264" = "ffmpeg:${name}#video=h264#hardware=cuda#audio=copy";
            })
          cfg.cameras;
        };
      };

      systemd.services.go2rtc.serviceConfig.LoadCredential =
        lib.mapAttrsToList (name: cam: "${name}_password:${cam.passwordFile}") cfg.cameras;

      systemd.services.frigate = {
        wants = ["go2rtc.service"];
        unitConfig.RequiresMountsFor = [recordingsMount cacheDir];
        serviceConfig = {
          ReadWritePaths = [recordingsMount];
          # The CUDA driver JIT-loads kernels (scale_cuda's PTX) into
          # writable+executable memory. The upstream module sets this plainly,
          # so only mkForce can lift it.
          MemoryDenyWriteExecute = lib.mkIf cfg.nvidia (lib.mkForce false);
        };
      };

      services.frigate = {
        enable = true;
        inherit (cfg) hostname package;
        settings = {
          mqtt.enabled = false;

          detectors.cpu = {
            type = "cpu";
            num_threads = 3;
          };

          # Explicit rather than "auto", which asks go2rtc at startup and so
          # depends on start order. Frigate applies it to the detect input only.
          ffmpeg.hwaccel_args = lib.mkDefault (
            if cfg.nvidia
            then "preset-nvidia"
            else []
          );

          record = {
            enabled = true;
            continuous.days = 0;
            # Keeps each 10 s segment that contains any motion; there is no
            # post-roll for this tier, only for alerts and detections below.
            motion.days = cfg.retainDays;
            alerts = retention;
            detections = retention;
            # Only timelapse exports are re-encoded; normal exports are copies.
            export.hwaccel_args =
              if cfg.nvidia
              then "preset-nvidia"
              else [];
          };

          snapshots = {
            enabled = true;
            retain.default = cfg.retainDays;
          };

          # Frigate validates live.streams against this list even though go2rtc
          # runs as its own service; the loopback restream keeps it secret-free.
          go2rtc.streams = lib.concatMapAttrs (name: _:
            {
              ${name} = [(restream name)];
              "${name}_sub" = [(restream "${name}_sub")];
            }
            // lib.optionalAttrs cfg.nvidia {
              "${name}_h264" = [(restream "${name}_h264")];
            })
          cfg.cameras;

          cameras =
            lib.mapAttrs (name: cam: {
              ffmpeg = {
                inputs = [
                  {
                    path = restream name;
                    input_args = "preset-rtsp-restream";
                    roles = ["record"];
                  }
                  {
                    path = restream "${name}_sub";
                    input_args = "preset-rtsp-restream";
                    roles = ["detect"];
                  }
                ];
                # Stream copy: recordings keep the camera's own encoding. Any
                # re-encode would be a second lossy generation.
                output_args.record = "preset-record-generic-audio-copy";
              };
              detect = {
                enabled = true;
                inherit (cam.detect) width height fps;
              };
              # Keys sort alphabetically into the YAML and the first is the
              # default view, so the H.264 stream that plays everywhere leads.
              live.streams =
                {"Full (main)" = name;}
                // (
                  if cfg.nvidia
                  then {
                    "Compatible (H.264)" = "${name}_h264";
                    "Low (sub)" = "${name}_sub";
                  }
                  else {"Compatible (sub)" = "${name}_sub";}
                );
            })
            cfg.cameras;
        };
      };
    };
  };
}
