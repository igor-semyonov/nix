{...}: {
  flake.nixosModules.ssh = {
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = true;
      };
    };
  };
}
