{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [inputs.nix-flatpak.homeManagerModules.nix-flatpak];

  config = lib.mkIf (!pkgs.stdenv.isDarwin) {
    services.flatpak = {
      enable = true;
      packages = [
        "org.libreoffice.LibreOffice"
        "com.obsproject.Studio"
        "org.prismlauncher.PrismLauncher"
        "com.discordapp.Discord"
      ];
      uninstallUnmanaged = true;
      update.auto = {
        enable = false;
        onCalendar = "weekly";
      };
    };

    home.packages = [pkgs.flatpak];

    xdg.systemDirs.data = [
      "/var/lib/flatpak/exports/share"
      "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
    ];
  };
}
