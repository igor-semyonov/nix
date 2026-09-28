{...}: {
  flake.nixosModules.sound-fiio-k9 = let
    # Rates the K9 can actually clock, from /proc/asound/card0/stream0. Guarded because an
    # unsupported rate does not fail -- pipewire just resamples everything to something the
    # device will take, which is silent and looks like a tuning problem rather than a typo.
    supported-rates = [44100 48000 88200 96000 176400 192000 352800 384000];

    # The single pinned graph rate. 44.1k is deliberate: it carries the bulk of Tidal --
    # 16/44.1 and 24/44.1 alike, the latter being much of what Tidal labels hi-res, since
    # the ex-MQA catalogue converted into 44.1/48k containers -- straight through at 1:1.
    # The fractional conversion lands on the 16kHz SAPI voices instead (AudioFormats=18,
    # SPSF_16kHz16BitMono, seen live as `S16LE 1 16000`), where 2.75625x on band-limited
    # mono speech is inaudible. Deliberately trading the signal we listen to for the one
    # we only need to understand.
    #
    # Everything else resamples to this. Measured over 70 resolved plays from the sone logs:
    # 65 at 44.1k, 2 at 48k, 3 at 96k -- so 93% of actual listening lands here at 1:1.
    sample-rate =
      if builtins.elem 44100 supported-rates
      then 44100
      else throw "sound-fiio-k9: the K9 does not advertise this rate";

    # Quantum is counted in frames, so latency is quantum/sample-rate -- a fixed frame count
    # does NOT mean fixed latency across rates (128 frames is 2.67ms at 48k, 2.90ms at
    # 44.1k, 1.33ms at 96k). Derive it from a target period instead, so moving `sample-rate`
    # between the 44.1k and 48k families holds the tuning put instead of silently changing it.
    target-period = 128.0 / 48000.0;

    # Pipewire accepts a non-power-of-two quantum but every documented tuning uses one, and
    # the ALSA period follows the quantum. 44100 lands on 117.6 frames -> 128.
    pow2-at-least = n: let
      go = p:
        if p >= n
        then p
        else go (p * 2);
    in
      go 1;

    default-quantum = pow2-at-least (target-period * sample-rate);
    min-quantum = default-quantum / 2;
    max-quantum = default-quantum * 2;

    # Speex sinc length. 4 is the pipewire default; 10 is transparent. Now carrying the TTS
    # path rather than music, which is exactly why it stays at 10 -- the fractional ratio
    # moved onto speech, so the good filter should follow it. Measured headroom is vast: the
    # whole graph busies ~20us against a ~2.9ms period.
    resample-quality = 10;

    sample-rate-str = toString sample-rate;
    default-quantum-str = toString default-quantum;
    max-quantum-str = toString max-quantum;
    min-quantum-str = toString min-quantum;
  in {
    boot.kernelParams = ["preempt=full"];
    security.rtkit.enable = true;
    services = {
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        # If you want to use JACK applications, uncomment this
        jack.enable = true;

        # use the example session manager (no others are packaged yet so this is enabled by default,
        # no need to redefine it in your config for now)
        # media-session.enable = true;

        extraConfig = {
          pipewire."92-low-latency" = {
            "context.properties" = {
              # No `default.clock.allowed-rates`, and adding it back does NOT work here --
              # this was tried and measured, not assumed. Retuning means closing and
              # reopening the ALSA device, but `session.suspend-timeout-seconds = 0` below
              # holds the K9 open permanently, so the moment pipewire would renegotiate in
              # never arrives. With allowed-rates set to [44100 48000 88200 96000 176400
              # 192000], a confirmed 24/96 FLAC (sone reporting `S24LE 2 96000`) left the
              # device sitting at 44100 and was resampled; `clock.rate` never moved. The
              # setting is inert against no-suspend, so it is omitted rather than left in
              # looking functional.
              #
              # The two are mutually exclusive: rate following requires letting the device
              # suspend, which reintroduces a wake click before every TTS utterance -- the
              # exact thing this module exists to prevent. Pinning wins.
              #
              # Same reason an exclusive-ALSA client (sone's bit-perfect mode) cannot take
              # the device: pipewire never lets go of it.
              "default.clock.rate" = sample-rate;
              "default.clock.quantum" = default-quantum;
              "default.clock.min-quantum" = min-quantum;
              "default.clock.max-quantum" = max-quantum;
            };
            "stream.properties" = {
              "resample.quality" = resample-quality;
            };
          };
          pipewire-pulse."92-low-latency" = {
            # "context.modules" = [
            #   {
            #     name = "libpipewire-module-protocol-pulse";
            #     args = {
            # "pulse.min.req" = "${default-quantum-str}/${sample-rate-str}";
            # "pulse.default.req" = "${default-quantum-str}/${sample-rate-str}";
            # "pulse.max.req" = "${default-quantum-str}/${sample-rate-str}";
            # "pulse.min.quantum" = "${min-quantum-str}/${sample-rate-str}";
            # "pulse.max.quantum" = "${max-quantum-str}/${sample-rate-str}";
            #     };
            #   }
            # ];
            "pulse.properties" = {
              "pulse.min.req" = "${default-quantum-str}/${sample-rate-str}";
              "pulse.default.req" = "${default-quantum-str}/${sample-rate-str}";
              "pulse.max.req" = "${default-quantum-str}/${sample-rate-str}";
              "pulse.min.quantum" = "${min-quantum-str}/${sample-rate-str}";
              "pulse.max.quantum" = "${max-quantum-str}/${sample-rate-str}";
            };
            # Only the resampler here. `node.latency` stays out of it: pulse.properties above
            # already sets the req/quantum for pulse clients, and pinning node.latency on top
            # forces it on every stream including ones happy to run larger buffers.
            "stream.properties" = {
              "resample.quality" = resample-quality;
            };
          };
        };
        wireplumber = {
          enable = true;
          extraConfig = {
            # "log-level-debug" = {
            #   "context.properties" = {
            #     # Output Debug log messages as opposed to only the default level (Notice)
            #     "log.level" = "D";
            #   };
            # };
            "no-suspend" = {
              "monitor.alsa.rules" = [
                {
                  matches = [
                    {
                      # "device.name" = "~alsa_card.*";
                      "node.name" = "~alsa_*";
                    }
                  ];
                  actions = {
                    update-props = {
                      "session.suspend-timeout-seconds" = 0;
                    };
                  };
                }
              ];
            };
          };
        };
      };
    };
  };
}
