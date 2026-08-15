{...}: {
  flake.nixosModules.ssh = {lib, ...}: {
    services.openssh = {
      enable = true;
      settings = {
        X11Forwarding = lib.mkDefault true;
      };
    };
  };
}
