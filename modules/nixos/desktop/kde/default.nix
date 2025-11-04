{pkgs, ...}: let
  wallpaper = ../../../home-manager/misc/wallpaper/wallpaper.jpg;
in {
  # Enable KDE
  services.displayManager.sddm = {
    enable = true;
    # enableHidpi = true;
    # settings.Theme.CursorTheme = "Yaru";
    settings.Theme.CursorTheme = "Bibata-Original-Amber-Right";
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = [
    # pkgs.yaru-theme
    pkgs.bibata-cursors
    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=${wallpaper};
      type=image
    '')
    pkgs.kdePackages.kcolorchooser
  ];

  # Excluding some KDE applications from the default install
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    ark
    baloo-widgets
    elisa
    # ffmpegthumbs
    kate
    # khelpcenter
    konsole
    krdp
    plasma-browser-integration
    # xwaylandvideobridge
  ];

  # Disabled redundant services
  systemd.user.services = {
    "app-org.kde.discover.notifier@autostart".enable = false;
    "app-org.kde.kalendarac@autostart".enable = false;
  };
}
