{...}: {
  flake.homeModules.ssh = {...}: {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*".addKeysToAgent = "yes";
        "fid" = {
          hostname = "10.0.0.1";
          user = "root";
        };
        "box" = {
          hostname = "boxy";
          user = "igor";
        };
        "tav" = {
          hostname = "tavore";
          user = "igor";
        };
        "let" = {
          hostname = "leto";
          user = "igor";
        };
        "syn" = {
          hostname = "synology";
          user = "igor";
        };
        "uri" = {
          hostname = "urithiru";
          user = "root";
        };
        hass = {
          hostname = "homeassistant.local";
          user = "root";
        };
        asano = {
          # hostname = "asano.home.nalgor.net";
          hostname = "192.168.50.48";
          user = "root";
        };
      };
    };
    services.ssh-agent.enable = true;
  };
}
