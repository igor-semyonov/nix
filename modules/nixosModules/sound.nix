{...}: {
  flake.nixosModules.sound-fiio-k9 = let
    # The single pinned graph rate. Must stay in the 48k family: the SAPI voices emit
    # 16kHz mono (AudioFormats=18, SPSF_16kHz16BitMono, confirmed live as `S16LE 1 16000`
    # in pw-top), which divides exactly into 48/96/192k. The 44.1k family would make Tidal
    # bit-exact but puts TTS on a non-integer ratio -- 88200/16000 = 5.5125 -- and TTS wins.
    sample-rate = 96000;

    # Quantum is counted in frames, so latency is quantum/sample-rate. Scaling the trio
    # with the rate holds latency at the tuned 128/48000 = 2.67ms whichever family member
    # `sample-rate` names, rather than silently changing it along with the rate.
    #
    # Integer division truncates, so `s * 48000 == sample-rate` is the divisibility check;
    # without it a 44.1k rate would yield a scale of 0 and a quantum of 0.
    rate-scale = let
      s = sample-rate / 48000;
    in
      if s > 0 && s * 48000 == sample-rate
      then s
      else throw "sound-fiio-k9: sample-rate ${toString sample-rate} is not a positive multiple of 48000; both the 16kHz TTS path and this quantum scaling assume the 48k family";

    default-quantum = 128 * rate-scale;
    max-quantum = 256 * rate-scale;
    min-quantum = 64 * rate-scale;

    # Speex sinc length. 4 is the pipewire default and is audible on the 44.1k material
    # that makes up most of Tidal; 10 is transparent. Measured headroom is vast -- the
    # whole graph busies ~20us against a 2.67ms period -- so the longer filter is free.
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
              # Deliberately no `default.clock.allowed-rates`: a single pinned rate means the
              # graph never renegotiates, so the K9 is never closed and reopened. Allowing
              # 44100 would be bit-exact for music but costs a relay click and a DAC re-lock
              # on every switch between a 44.1k source and TTS -- the thing this whole module
              # exists to avoid. 44.1k is resampled instead, at `resample-quality` below.
              #
              # The pin is also why the K9 stays open indefinitely, which is in turn why an
              # exclusive-ALSA client (sone's bit-perfect mode) cannot take the device.
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
