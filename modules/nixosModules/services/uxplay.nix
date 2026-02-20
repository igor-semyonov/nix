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
      publish = {
        enable = true;
        addresses = true;
        userServices = true; # Critical for uxplay to register itself
      };
    };
  };
}
