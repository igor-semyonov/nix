{
  inputs,
  config,
  ...
}: let
  ns = config.namespace-specifier;
in {
  flake.homeModules.flatpak = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [inputs.nix-flatpak.homeManagerModules.nix-flatpak];
    options.${ns}.flatpak = {
      packages = lib.mkOption {
        type = lib.types.listOf (lib.types.singleLineStr);
        description = "List of flatpak package specifiers to be installed";
        default = [];
      };
    };

    config = lib.mkIf (!pkgs.stdenv.isDarwin) {
      services.flatpak = {
        enable = true;
        packages = config.${ns}.flatpak.packages;
        uninstallUnmanaged = true;
        update.auto = {
          enable = true;
          onCalendar = "weekly";
        };
      };

      home.packages = [pkgs.flatpak];

      xdg.systemDirs.data = [
        "/var/lib/flatpak/exports/share"
        "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
      ];
    };
  };
}
