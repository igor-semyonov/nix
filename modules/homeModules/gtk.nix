{...}: {
  flake.homeModules.gtk = {
    config,
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
      "file:///home/${config.userConfig.name}/Documents"
      "file:///home/${config.userConfig.name}/Downloads"
      "file:///home/${config.userConfig.name}/nalgor"
      "file:///home/${config.userConfig.name}/db"
      "file:///home/${config.userConfig.name}/code"
      # "file:///home/${config.userConfig.name}/Pictures"
      # "file:///home/${config.userConfig.name}/Videos"
      # "file:///home/${config.userConfig.name}/Downloads/temp"
      # "file:///home/${config.userConfig.name}/Documents/repositories"
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
        gtk2 = fullTheme // {force = true;};
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
  };
}
