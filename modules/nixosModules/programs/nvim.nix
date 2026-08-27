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
      variant = lib.mkOption {
        type = lib.types.enum (
          builtins.attrNames inputs.my-nvim.packages.${pkgs.stdenv.hostPlatform.system}
        );
        default = "default";
        description = ''
          Which build from the nvim flake to install, by output name -- currently
          `default`, `minimal`, `neovim` or `nightly`.

          The enum is read from the flake's own outputs, so a variant added there is
          selectable here with no change, and a typo fails at eval listing the valid names
          rather than at build time.

          `minimal` is the one for a remote or resource-constrained host. Sets `package`
          below; set `package` directly to install something this enum cannot name.
        '';
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = inputs.my-nvim.packages.${pkgs.stdenv.hostPlatform.system}.${cfg.variant};
        defaultText = lib.literalExpression ''inputs.my-nvim.packages.$\{system}.$\{cfg.variant}'';
        description = "The neovim package to be used. Defaults to the `variant` selection.";
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
