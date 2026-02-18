{
  config,
  lib,
  pkgs,
  ...
}: let
  sample-rate = 48000;
  default-quantum = 128;
  max-quantum = 256;
  min-quantum = 64;

  sample-rate-str = builtins.toString sample-rate;
  default-quantum-str = builtins.toString default-quantum;
  max-quantum-str = builtins.toString max-quantum;
  min-quantum-str = builtins.toString min-quantum;
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
            "default.clock.rate" = sample-rate;
            "default.clock.quantum" = default-quantum;
            "default.clock.min-quantum" = min-quantum;
            "default.clock.max-quantum" = max-quantum;
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
          # "stream.properties" = {
          #   "node.latency" = "${default-quantum-str}/${sample-rate-str}";
          #   "resample.quality" = 1;
          # };
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
}
