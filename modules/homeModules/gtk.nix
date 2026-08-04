{...}: {
  flake.homeModules.gtk = {
    config,
    pkgs,
    ...
  }: let
    theme = {
      name = "Dracula";
      package = pkgs.dracula-theme;
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
    # fullTheme = {
    #   inherit theme iconTheme cursorTheme;
    # };
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
    # # GTK theme configuration
    # gtk = {
    #   enable = true;
    #   inherit theme cursorTheme iconTheme;
    #   font = {
    #     name = "Roboto";
    #     size = 14;
    #   };
    #   gtk2 = {force = true;};
    #   gtk3 = {inherit bookmarks;};

    #   # probably don't need this
    #   # gtk2 = fullTheme // {force = true;};
    #   # gtk3 = fullTheme // {inherit bookmarks;};
    #   # gtk4 = fullTheme;
    # };
  };
}
