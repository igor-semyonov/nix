{...}: {
  flake.nixosModules.programs-thunderbird = {pkgs, ...}: {
    programs.thunderbird = {
      enable = true;
      package = pkgs.thunderbird-bin;
    };
  };
}
