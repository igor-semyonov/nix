{
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (!pkgs.stdenv.isDarwin) {
    qt = {
      enable = true;
      # platformTheme.name = "kvantum";
      # style.name = "kvantum";
      platformTheme.name = "kde";
      style.name = "Breeze";
    };

    home.sessionVariables = {
      # use wayland as the default backend, fallback to xcb if wayland is not available
      QT_QPA_PLATFORM = "wayland;xcb";

      # remain backwards compatible with qt5
      DISABLE_QT5_COMPAT = "0";

      # tell calibre to use the dark theme
      CALIBRE_USE_DARK_PALETTE = "1";
    };
  };
}
