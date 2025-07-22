{
  userConfig,
  pkgs,
  ...
}: {
  # GTK theme configuration
  gtk = {
    enable = true;
    iconTheme = {
      name = "Tela-circle-dark";
      package = pkgs.tela-circle-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Original-Amber-Right";
      package = pkgs.bibata-cursors;
      size = 96;
    };
    font = {
      name = "Roboto";
      size = 14;
    };
    gtk3 = {
      bookmarks = [
        # "file:///home/${userConfig.name}/Documents"
        "file:///home/${userConfig.name}/Downloads"
        # "file:///home/${userConfig.name}/Pictures"
        # "file:///home/${userConfig.name}/Videos"
        # "file:///home/${userConfig.name}/Downloads/temp"
        # "file:///home/${userConfig.name}/Documents/repositories"
      ];
    };
  };

  # Enable catppuccin theming for GTK apps.
  catppuccin.gtk.enable = true;
}
