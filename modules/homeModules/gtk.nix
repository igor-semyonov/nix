{...}: {
  flake.homeModules.gtk = {config, ...}: let
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
    gtk = {
      enable = true;
      gtk3 = {inherit bookmarks;};
    };
  };
}
