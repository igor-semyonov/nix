{
  pkgs,
  config,
  nhModules,
  userConfig,
  ...
}: {
  imports = [
    "${nhModules}/programs/alacritty"
  ];

  # Enable home-manager
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
  home = {
    username = "${userConfig.name}";
    homeDirectory = "/home/${userConfig.name}";
  };

  # flatpak
  home.packages = [pkgs.flatpak];
  services.flatpak = {
    enable = true;
    packages = [
    ];
    uninstallUnmanaged = false;
    update.auto = {
      enable = false;
      onCalendar = "weekly";
    };
  };
  xdg.systemDirs.data = [
    "/var/lib/flatpak/exports/share"
    "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
