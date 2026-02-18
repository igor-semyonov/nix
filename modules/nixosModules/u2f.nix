{...}: {
  flake.nixosModules.u2f = {
    security.pam = {
      u2f = {
        enable = true;
        control = "sufficient";
        settings = {
          cue = true;
        };
      };
      services.sddm.u2fAuth = false;
    };
  };
}
