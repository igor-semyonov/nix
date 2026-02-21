{...}: {
  flake.homeModules.bat = {...}: {
    # Install bat via home-manager module
    programs.bat = {
      enable = true;
    };
  };
}
