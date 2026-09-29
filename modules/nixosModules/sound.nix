{...}: {
  flake.nixosModules.sound = {
    lib,
    pkgs,
    config,
    ...
  }: let
    cfg = config.igix.sound;

    # 128 frames at 48kHz = 2.67ms. Quantum is counted in frames, so a fixed frame count is
    # NOT a fixed latency across rates -- 128 frames is 2.67ms at 48k but 1.33ms at 96k.
    # Deriving from a target period keeps the tuning put as `sampleRate` moves.
    target-period = 128.0 / 48000.0;

    # Pipewire accepts a non-power-of-two quantum, but every documented tuning uses one and
    # the ALSA period follows it. 44100 lands on 117.6 frames -> 128.
    pow2-at-least = n: let
      go = p:
        if p >= n
        then p
        else go (p * 2);
    in
      go 1;

    # Rates each known DAC can clock for PCM, verified on hardware. Naming a device seeds
    # `allowedRates` correctly instead of guessing; every value stays overridable. Add a
    # device by adding an entry -- nothing else keys off the name.
    #
    # Verify with pink noise at each candidate rate, targeting the sink directly:
    #   sox -n -r <rate> -c 2 -b 24 t.wav synth 6 pinknoise vol 0.06
    #   pw-play --target <sink> t.wav &
    #   pactl suspend-sink <sink> 1; sleep 0.4; pactl suspend-sink <sink> 0
    #   grep ^rate /proc/asound/card<N>/pcm0p/sub0/hw_params
    #
    # CRITICAL: the rate under test must already be in the live `allowed-rates` or the
    # result is meaningless. Pipewire silently falls back to the highest allowed rate in
    # the SAME FAMILY -- 352800 and 705600 become 176400, 384000 and 768000 become 192000.
    # That looks exactly like a hardware ceiling with neat halving, and is not one. Both
    # DACs below were briefly mis-measured as capping at 192000 for precisely this reason;
    # with the rates actually allowed, every entry here works.
    # `match` is a wireplumber node.name pattern; `~` prefixes a regex.
    known-devices = {
      fiio-k9 = {
        match = "~alsa_output\\.usb-.*FiiO_K9.*";
        rates = [44100 48000 88200 96000 176400 192000 352800 384000 705600 768000];
      };
      questyle-m15i = {
        match = "~alsa_output\\.usb-.*M15i.*";
        rates = [44100 48000 88200 96000 176400 192000 352800 384000 705600 768000];
      };
    };

    # Union of every declared device's rates, so the graph clock can reach anything any
    # attached device can do. Per-device `audio.allowed-rates` then stops each one being
    # dragged past its own ceiling -- the graph list alone cannot express "this DAC does
    # 768k but the internal codec stops at 192k".
    declared-rates = let
      lists = lib.filter (r: r != null) (lib.mapAttrsToList (_: d: d.allowedRates) cfg.devices);
    in
      lib.sort (a: b: a < b) (lib.unique (lib.concatLists lists));

    # Conservative set for an unnamed device: the two families everything supports, plus
    # their first doubling.
    generic-rates = [44100 48000 88200 96000];

    rate-str = toString cfg.sampleRate;
    quantum-str = toString cfg.quantum;
    min-quantum-str = toString cfg.minQuantum;
    max-quantum-str = toString cfg.maxQuantum;

    # Retunes the DAC to match whatever is playing. Needed because an ALSA device's rate is
    # fixed when it is opened: pipewire can only change it by closing and reopening, which
    # normally only happens on the idle-suspend timeout. With `suspendTimeout = 0` that
    # timeout never fires, so nothing ever retunes on its own -- but `pactl suspend-sink`
    # still forces the cycle on demand, and unlike a device-profile cycle it leaves active
    # streams connected.
    #
    # Detection is player-agnostic: a sink-input reports its SOURCE rate, not the device's,
    # so a 44.1k stream feeding a 96k device is directly visible.
    retune = pkgs.writeShellApplication {
      name = "dac-retune";
      runtimeInputs = [pkgs.pulseaudio pkgs.gawk pkgs.coreutils];
      text = ''
        allowed="${toString cfg.allowedRates}"

        # Rate the device is currently clocked at.
        sink_rate() {
          pactl list sinks | awk -v w="$1" '
            /^Sink #/          { mine = 0 }
            /^[ \t]*Name: /    { mine = ($2 == w) }
            mine && /Sample Specification:/ { gsub(/Hz/, "", $NF); print $NF; exit }
          '
        }

        # Source rates of the streams attached to that sink, EXCLUDING corked ones.
        #
        # Corked means paused, and a paused stream keeps its sink-input alive indefinitely
        # with its original rate. A backgrounded browser tab therefore looks exactly like
        # something demanding a rate change forever: the device gets retuned, pipewire
        # returns the idle device to `default.clock.rate`, the mismatch reappears, and it
        # cycles endlessly -- closing the device each time and eating the start of anything
        # short that plays in between. Debouncing does not help, since a corked stream is
        # present on every poll, not just transiently.
        #
        # `Corked:` comes after `Sample Specification:` in each block, so the rate has to be
        # held and emitted at the block boundary rather than on sight.
        stream_rates() {
          pactl list sink-inputs | awk -v s="$1" '
            function flush() { if (mine && rate != "" && corked == "no") print rate }
            /^Sink Input #/          { flush(); mine = 0; rate = ""; corked = "" }
            /^[ \t]*Sink: /          { mine = ($2 == s) }
            /Sample Specification:/  { gsub(/Hz/, "", $NF); rate = $NF }
            /^[ \t]*Corked: /        { corked = $2 }
            END                      { flush() }
          ' | sort -u
        }

        # Previous poll's candidate, so a mismatch must persist across two checks before we
        # act. A stream's reported rate is not stable the instant it appears, and acting on
        # that transient cycled the device in the middle of short utterances -- inaudible
        # for music, but it ate the first word of every speech-synthesis run.
        previous=""

        while :; do
          sink=$(pactl get-default-sink 2>/dev/null || true)
          if [ -n "$sink" ]; then
            idx=$(pactl list short sinks | awk -v w="$sink" '$2 == w { print $1; exit }')
            dev=$(sink_rate "$sink")

            # Only rates we are permitted to switch to count. This is what keeps the 16kHz
            # TTS voices from ever triggering a retune: no DAC clocks 16k, so it is never
            # in `allowedRates` and is simply resampled to whatever is running.
            wanted=""
            for r in $(stream_rates "$idx"); do
              case " $allowed " in
                *" $r "*) wanted="$wanted $r" ;;
              esac
            done
            # shellcheck disable=SC2086
            set -- $wanted

            # Exactly one candidate, and it disagrees with the hardware. Two streams at
            # different rates is ambiguous -- leave it resampling rather than thrash.
            if [ "$#" -eq 1 ] && [ -n "$dev" ] && [ "$1" != "$dev" ]; then
              if [ "$1" = "$previous" ]; then
                pactl suspend-sink "$sink" 1
                sleep 0.3
                pactl suspend-sink "$sink" 0
                previous=""
                sleep ${toString cfg.autoRetune.cooldown}
              else
                previous="$1"
              fi
            else
              previous=""
            fi
          fi
          sleep ${toString cfg.autoRetune.interval}
        done
      '';
    };
  in {
    options.igix.sound = {
      enable =
        lib.mkEnableOption "low-latency pipewire tuned for a fixed-rate DAC"
        // {default = true;};

      sampleRate = lib.mkOption {
        type = lib.types.ints.positive;
        default = 44100;
        description = ''
          Rate the graph idles at and falls back to. Anything not matching is resampled to
          it, so this should be whatever the bulk of the material actually is.

          44.1k suits a streaming library: it carries 16/44.1 and 24/44.1 alike -- the
          latter being much of what services label hi-res, since ex-MQA catalogues
          converted into 44.1/48k containers -- through at 1:1. It pushes the fractional
          conversion onto 16kHz speech synthesis instead, where it is inaudible.
        '';
      };

      knownDeviceRates = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.ints.positive);
        readOnly = true;
        default = lib.mapAttrs (_: d: d.rates) known-devices;
        description = ''
          PCM rate lists measured on real hardware for the DACs this module ships profiles
          for. Read-only; exposed so a consumer can reference a known-good list rather than
          copying `/proc/asound/card*/stream*`, which reports modes the device cannot
          necessarily clock.
        '';
      };

      devices = lib.mkOption {
        default = {};
        description = ''
          Per-output overrides, one entry per attached device. Empty means a single global
          policy for every ALSA node, which is fine for a host with one fixed output.

          Declare an entry per output on a machine whose outputs differ -- a laptop with an
          internal codec, a USB DAC, and sometimes neither. Each entry becomes one
          wireplumber `monitor.alsa.rules` match, applied after the global rule, so it
          overrides it for the nodes it matches.

          An entry named after a key in `knownDeviceRates` inherits that profile's match
          pattern and rates, so `devices.fiio-k9 = {}` is enough. Any other name needs at
          least `match`.
        '';
        example = lib.literalExpression ''
          {
            fiio-k9 = {}; # known profile, nothing to state
            internal = {
              match = "~alsa_output\\.pci-.*";
              allowedRates = [44100 48000 96000];
              suspendTimeout = 5; # let the internal codec idle down
            };
          }
        '';
        type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
          options = {
            match = lib.mkOption {
              type = lib.types.str;
              default =
                known-devices.${name}.match
                or (throw "igix.sound.devices.${name}: no built-in profile by that name, so `match` must be set -- a wireplumber node.name pattern, e.g. \"~alsa_output\\\\.pci-.*\" (find yours with `pactl list short sinks`). Built-in profiles: ${lib.concatStringsSep ", " (builtins.attrNames known-devices)}");
              defaultText = lib.literalExpression "the matching `knownDeviceRates` entry's pattern, if the attribute name is one";
              example = "~alsa_output\\.pci-.*";
              description = ''
                Wireplumber `node.name` pattern selecting this device. A `~` prefix makes
                it a regex. Find the name with `pactl list short sinks`.
              '';
            };

            allowedRates = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.ints.positive);
              default = known-devices.${name}.rates or null;
              defaultText = lib.literalExpression "the matching `knownDeviceRates` entry, if the attribute name is one, else null";
              description = ''
                Rates this device may be clocked at, as `audio.allowed-rates`. null leaves
                it unconstrained and it follows the graph-wide `allowedRates`.

                Measure rather than trusting `/proc` -- and note a rate absent from the
                graph-wide list can never be selected here, so verify with it present or
                pipewire's same-family fallback will fake a ceiling.
              '';
            };

            rate = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = ''
                Rate this device idles at, as `audio.rate`. null follows the graph-wide
                `sampleRate`. Useful where one output's natural rate differs from the
                host's -- an internal codec at 48k beside a 44.1k-centric library.
              '';
            };

            suspendTimeout = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.unsigned;
              default = null;
              description = ''
                Per-device override of the global `suspendTimeout`. null inherits it.

                A DAC used for speech synthesis wants 0 so nothing is clipped on wake; a
                battery-powered internal codec usually wants to idle down instead.
              '';
            };
          };
        }));
      };

      allowedRates = lib.mkOption {
        type = lib.types.listOf lib.types.ints.positive;
        default =
          if declared-rates != []
          then declared-rates
          else generic-rates;
        defaultText = lib.literalExpression ''
          the union of every `devices.*.allowedRates`, or ${builtins.toJSON generic-rates}
          when no devices are declared
        '';
        description = ''
          Rates the device may be retuned to when a stream wants one, on top of
          `sampleRate`. Must include `sampleRate`. Empty pins the graph entirely.

          Every entry must be one the hardware can clock -- check
          `/proc/asound/card*/stream*` for `Rates:`. An unsupported rate does not fail
          loudly, it just resamples, which reads as a tuning problem rather than a typo.
          Setting `device` picks a correct list automatically.

          Listing a rate nothing streams at costs nothing: the watcher only retunes to a
          rate some stream is actually asking for.

          Note this is inert on its own when `suspendTimeout` is 0; see `autoRetune`.
        '';
      };

      quantum = lib.mkOption {
        type = lib.types.ints.positive;
        default = pow2-at-least (target-period * cfg.sampleRate);
        defaultText = lib.literalExpression ''
          the power of two nearest a 2.67ms period at `sampleRate`
          (128 at 44.1k/48k, 256 at 88.2k/96k, 512 at 176.4k/192k)
        '';
        description = "Graph quantum in frames. Latency is `quantum / sampleRate`.";
      };

      minQuantum = lib.mkOption {
        type = lib.types.ints.positive;
        default = cfg.quantum / 2;
        defaultText = lib.literalExpression "`quantum` / 2";
        description = "Smallest quantum pipewire may negotiate down to.";
      };

      maxQuantum = lib.mkOption {
        type = lib.types.ints.positive;
        default = cfg.quantum * 2;
        defaultText = lib.literalExpression "`quantum` * 2";
        description = ''
          Largest quantum pipewire may negotiate up to. Players asking for a big buffer
          pull the graph here, so this sets the real-world period during playback.
        '';
      };

      resampleQuality = lib.mkOption {
        type = lib.types.ints.between 0 15;
        default = 10;
        description = ''
          Speex sinc length. 4 is the pipewire default; 10 is transparent and costs little
          against a multi-millisecond period.
        '';
      };

      suspendTimeout = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = ''
          Seconds of silence before wireplumber closes an ALSA device. 0 never closes it.

          0 is the right default for a machine doing frequent short playback such as speech
          synthesis: a suspended DAC needs a few hundred milliseconds to re-lock on wake,
          and the opening syllables are lost into that gap.

          The cost is that automatic rate following stops working, because retuning
          requires the close/reopen this prevents. `autoRetune` exists to get it back
          without reintroducing the wake gap; a non-zero value here is the cruder
          alternative.
        '';
      };

      autoRetune = {
        enable =
          lib.mkEnableOption ''
            a user service that retunes the DAC to match what is playing, by forcing a
            suspend/resume cycle on the sink. Restores rate following when `suspendTimeout`
            is 0, without the wake gap an idle timeout would cause
          ''
          // {
            default = cfg.suspendTimeout == 0 && cfg.allowedRates != [];
            defaultText = lib.literalExpression "`suspendTimeout == 0 && allowedRates != []`";
          };

        interval = lib.mkOption {
          type = lib.types.ints.positive;
          default = 2;
          description = "Seconds between checks. Each is two short `pactl` invocations.";
        };

        cooldown = lib.mkOption {
          type = lib.types.ints.positive;
          default = 10;
          description = ''
            Seconds to wait after retuning before checking again, so a player that briefly
            reports an odd rate while starting cannot cause repeated cycling.
          '';
        };
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.allowedRates == [] || builtins.elem cfg.sampleRate cfg.allowedRates;
          message = "igix.sound: sampleRate (${rate-str}) must appear in allowedRates, or allowedRates must be empty";
        }
        {
          assertion = cfg.minQuantum <= cfg.quantum && cfg.quantum <= cfg.maxQuantum;
          message = "igix.sound: require minQuantum <= quantum <= maxQuantum, got ${min-quantum-str} / ${quantum-str} / ${max-quantum-str}";
        }
        {
          assertion = !cfg.autoRetune.enable || cfg.allowedRates != [];
          message = "igix.sound: autoRetune needs a non-empty allowedRates to have anything to switch to";
        }
      ];

      # Full preemption keeps the audio thread's wakeups honest at a sub-3ms period.
      boot.kernelParams = ["preempt=full"];
      security.rtkit.enable = true;

      # pactl is the only supported way to force a rate renegotiation on an open device, and
      # it is what `dac-retune` drives. The daemon is not used -- pipewire-pulse replaces it.
      environment.systemPackages = [pkgs.pulseaudio] ++ lib.optional cfg.autoRetune.enable retune;

      # A user unit is enabled for every user that gets a systemd user manager -- there is
      # no isNormalUser filter at this layer. Rather than start for every session and spin
      # uselessly where there is no audio, this hangs off pipewire itself: `wantedBy` pulls
      # it in only when that user's pipewire starts, and `partOf` takes it back down with
      # it. ConditionUser additionally keeps it away from system accounts, which can end up
      # with a user manager via lingering or PAMName.
      systemd.user.services.dac-retune = lib.mkIf cfg.autoRetune.enable {
        description = "Retune the DAC to match the playing stream's sample rate";
        wantedBy = ["pipewire.service"];
        partOf = ["pipewire.service"];
        after = ["pipewire.service" "wireplumber.service"];
        unitConfig.ConditionUser = "!@system";
        serviceConfig = {
          ExecStart = "${retune}/bin/dac-retune";
          Restart = "always";
          RestartSec = 5;
          # Nothing here needs privilege or persistence beyond talking to the user's own
          # pipewire socket.
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          NoNewPrivileges = true;
        };
      };

      services = {
        pulseaudio.enable = false;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;

          extraConfig = {
            pipewire."92-low-latency" = {
              "context.properties" =
                {
                  "default.clock.rate" = cfg.sampleRate;
                  "default.clock.quantum" = cfg.quantum;
                  "default.clock.min-quantum" = cfg.minQuantum;
                  "default.clock.max-quantum" = cfg.maxQuantum;
                }
                // lib.optionalAttrs (cfg.allowedRates != []) {
                  "default.clock.allowed-rates" = cfg.allowedRates;
                };
              "stream.properties" = {
                "resample.quality" = cfg.resampleQuality;
              };
            };
            pipewire-pulse."92-low-latency" = {
              "pulse.properties" = {
                "pulse.min.req" = "${quantum-str}/${rate-str}";
                "pulse.default.req" = "${quantum-str}/${rate-str}";
                "pulse.max.req" = "${quantum-str}/${rate-str}";
                "pulse.min.quantum" = "${min-quantum-str}/${rate-str}";
                "pulse.max.quantum" = "${max-quantum-str}/${rate-str}";
              };
              # Only the resampler here. `node.latency` stays out: pulse.properties above
              # already sets the req/quantum, and pinning node.latency on top forces it on
              # every stream including ones happy to run larger buffers.
              "stream.properties" = {
                "resample.quality" = cfg.resampleQuality;
              };
            };
          };

          wireplumber = {
            enable = true;
            # Global rule first, per-device rules after: wireplumber applies them in order,
            # so a later match overrides an earlier one for the nodes it covers.
            extraConfig."device-rules" = {
              "monitor.alsa.rules" =
                [
                  {
                    matches = [{"node.name" = "~alsa_*";}];
                    actions.update-props."session.suspend-timeout-seconds" = cfg.suspendTimeout;
                  }
                ]
                ++ (lib.mapAttrsToList (_: d: {
                    matches = [{"node.name" = d.match;}];
                    actions.update-props =
                      lib.optionalAttrs (d.suspendTimeout != null) {
                        "session.suspend-timeout-seconds" = d.suspendTimeout;
                      }
                      // lib.optionalAttrs (d.allowedRates != null) {
                        "audio.allowed-rates" = d.allowedRates;
                      }
                      // lib.optionalAttrs (d.rate != null) {
                        "audio.rate" = d.rate;
                      };
                  })
                  cfg.devices);
            };
          };
        };
      };
    };
  };
}
