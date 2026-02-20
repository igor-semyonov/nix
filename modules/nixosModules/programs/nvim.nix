{inputs, ...}: {
  flake.nixosModules.programs-nvim = {pkgs, ...}: {
    environment = {
      systemPackages = [
        inputs.my-nvim.packages.${pkgs.stdenv.hostPlatform.system}.nvim-nixcats
      ];
      variables = {
        EDITOR = "vim";
        VISUAL = "vim";
        SYSTEMD_EDITOR = "vim";
      };
    };
  };
}
