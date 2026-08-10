{inputs, ...}: let
  variables = {
    EDITOR = "vim";
    VISUAL = "vim";
    SYSTEMD_EDITOR = "vim";
  };
in {
  flake.nixosModules.programs-nvim = {
    pkgs,
    lib,
    config,
    ...
  }: let
    cfg = config.igix.nvim;
  in {
    options.igix.nvim = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = inputs.my-nvim.packages.${pkgs.stdenv.hostPlatform.system}.default;
        description = "The neovim package to be used";
      };
    };
    config = lib.mkIf cfg.enable {
      environment = {
        inherit variables;
        systemPackages = [
          cfg.package
        ];
      };
    };
  };
}
