{...}: {
  flake.nixosModules.uxplay = {pkgs, ...}: {
    environment.systemPackages = [pkgs.uxplay];
    networking.firewall = {
      allowedTCPPorts = [7000 7001 7100];
      allowedUDPPorts = [6000 6001 7011];
    };
    services.avahi = {
      enable = true;
      nssmdns4 = true; # Allows software to find .local domains
      openFirewall = true; # Opens UDP port 5353 for mDNS
      # `settings` is freeform, so these must be avahi-daemon.conf keys, not the
      # old publish.{enable,addresses,userServices} option names — those pass
      # through as invalid keys and leave disable-publishing at its default true.
      settings.publish = {
        disable-publishing = false;
        disable-user-service-publishing = false; # uxplay registers itself
        publish-addresses = true;
      };
    };
  };
}
