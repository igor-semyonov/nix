{...}: {
  flake.homeModules.abs-tract = {
    lib,
    config,
    ...
  }: let
    cfg = config.igix.abs-tract;
  in {
    options.igix.abs-tract = {
      enable = lib.mkEnableOption "abs-tract, an Audiobookshelf metadata provider, as a rootless Podman container";
      image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/arranhs/abs-tract:latest";
        description = "Container image to run.";
      };
      address = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          Host address to publish the container port on. Loopback suffices when
          Audiobookshelf runs on the same host. Widening this needs a matching
          `networking.firewall.allowedTCPPorts` entry: rootless Podman publishes
          through an ordinary userspace socket, so unlike Docker it does not
          install its own iptables rules bypassing the host firewall.
        '';
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5555;
        description = "Host port to publish abs-tract on.";
      };
      autoUpdate = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Pull a newer `:latest` on a timer and restart the container. Off by
          default to match the Docker setup this replaced, which never updated
          the image on its own.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      services.podman = {
        enable = true;
        # The per-container autoUpdate label is inert without this timer.
        autoUpdate.enable = cfg.autoUpdate;
        containers.abs-tract = {
          inherit (cfg) image;
          description = "Audiobookshelf metadata provider";
          ports = ["${cfg.address}:${toString cfg.port}:5555/tcp"];
          # Only takes effect at boot if the user has linger enabled.
          autoStart = true;
          autoUpdate = lib.mkIf cfg.autoUpdate "registry";
        };
      };
    };
  };
}
