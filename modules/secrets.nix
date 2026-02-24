{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.secrets = {config, ...}: {
    imports = [inputs.sops-nix.nixosModules.sops];

    sops = {
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      defaultSopsFile = "${self}/.secrets/default.yaml";
      defaultSopsFormat = "yaml";
      secrets = {
        wifi-turtle-reef = {};
      };
    };

    sops.templates."wifi-credentials.env".content = ''
      WIFI_PSK=${config.sops.placeholder.wifi-turtle-reef}
    '';
    networking.networkmanager.enable = true;
    networking.networkmanager.wifi.backend = "iwd";
    hardware.enableRedistributableFirmware = true;
    networking.networkmanager.ensureProfiles = {
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
            # key-mgmt = "wpa-psk"; # WPA2
            key-mgmt = "sae"; # WPA3
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
}
