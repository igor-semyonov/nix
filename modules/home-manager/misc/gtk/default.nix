{
  userConfig,
  pkgs,
  ...
}: let
  theme = {
    name = "Sweet-Dark";
    package = pkgs.sweet;
  };
  cursorTheme = {
    name = "Bibata-Original-Amber-Right";
    package = pkgs.bibata-cursors;
    size = 96;
  };
  iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-nord;
  };
  fullTheme = {
    theme = theme;
    cursorTheme = cursorTheme;
    iconTheme = iconTheme;
  };
  bookmarks = [
    "file:///home/${userConfig.name}/Documents"
    "file:///home/${userConfig.name}/Downloads"
    # "file:///home/${userConfig.name}/Pictures"
    # "file:///home/${userConfig.name}/Videos"
    # "file:///home/${userConfig.name}/Downloads/temp"
    # "file:///home/${userConfig.name}/Documents/repositories"
  ];
in {
  # GTK theme configuration
  gtk =
    fullTheme
    // {
      enable = true;
      font = {
        name = "Roboto";
        size = 14;
      };
      gtk2 = fullTheme;
      gtk4 =
        fullTheme
        // {
          theme = {
            package = pkgs.sweet;
            name = "Sweet-Dark-v40";
          };
        };
      gtk3 =
        fullTheme
        // {
          bookmarks = bookmarks;
        };
    };
}
