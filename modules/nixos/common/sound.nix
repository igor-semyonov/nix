{
  config,
  lib,
  pkgs,
  ...
}: let
  sample-rate = 48000;
  bit-depth = 32;
  default-quantum = 512;
  max-quantum = 2048;
  min-quantum = 128;

  sample-rate-str = builtins.toString sample-rate;
  default-quantum-str = builtins.toString default-quantum;
  max-quantum-str = builtins.toString max-quantum;
  min-quantum-str = builtins.toString min-quantum;
  bit-depth-str = builtins.toString bit-depth;
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
          "context.modules" = [
            {
              name = "libpipewire-module-protocol-pulse";
              args = {
                "pulse.min.req" = "${default-quantum-str}/${sample-rate-str}";
                "pulse.default.req" = "${default-quantum-str}/${sample-rate-str}";
                "pulse.max.req" = "${default-quantum-str}/${sample-rate-str}";
                "pulse.min.quantum" = "${min-quantum-str}/${sample-rate-str}";
                "pulse.max.quantum" = "${max-quantum-str}/${sample-rate-str}";
              };
            }
          ];
          "stream.properties" = {
            "node.latency" = "${default-quantum-str}/${sample-rate-str}";
            "resample.quality" = 1;
          };
        };
      };
    };
  };
}
