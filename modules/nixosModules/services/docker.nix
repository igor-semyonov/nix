{...}: {
  flake.nixosModules.docker = {lib, ...}: {
    virtualisation = {
      docker = {
        # mkDefault so hosts can opt out without mkForce.
        enable = lib.mkDefault true;
        # rootless = {
        #   enable = true;
        #   setSocketVariable = true;
        # };
      };
    };
  };
}
