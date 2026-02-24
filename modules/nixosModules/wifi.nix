{config, ...}: let
  ns = config.namespace-specifier;
in {
  flake.nixosModules.wifi = {
    config,
    lib,
    ...
  }: let
    cfg = config.${ns}.wifi;
  in {
    options.${ns}.wifi = {
      enable = lib.mkEnableOption "Enable wifi";
      backend = lib.mkOption {
        description = "Wifi backend";
        type = lib.types.enum [
          "wpa_supplicant"
          "iwd"
        ];
        default = "iwd";
      };
      key-mgmt = lib.mkOption {
        type = lib.types.enum [
          "wpa-psk" # WPA2
          "sae" # WPA3
        ];
        default = "sae";
        description = "Which standard to ouse for connections, rae means wpa3 and wpa-psk menas wpa2";
      };
    };
    config = lib.mkIf cfg.enable {
      hardware.enableRedistributableFirmware = true;
      sops.templates."wifi-credentials.env".content = ''
        WIFI_PSK=${config.sops.placeholder.wifi-turtle-reef}
      '';
      networking.networkmanager = {
        enable = true;
        wifi.backend = cfg.backend;
        ensureProfiles = {
          environmentFiles = [
            config.sops.templates."wifi-credentials.env".path
          ];
          profiles = {
            "TurtleReef" = {
              connection = {
                id = "TurtleReef";
                type = "wifi";
              };
              wifi = {
                ssid = "Turtle Reef";
                mode = "infrastructure";
              };
              wifi-security = {
                key-mgmt = cfg.keymgmt; # WPA3

                # The $ variable matches the key in the sops template
                psk = "$WIFI_PSK";
              };
              ipv4 = {
                method = "auto";
              };
              ipv6 = {
                method = "auto";
              };
            };
          };
        };
      };
    };
  };
}
