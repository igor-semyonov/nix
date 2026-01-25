{
  nhModules,
  lib,
  ...
}: {
  imports = [
    "${nhModules}/common"
    "${nhModules}/desktop/kde"
    # "${nhModules}/desktop/hyprland"
  ];

  # Enable home-manager
  programs.home-manager.enable = true;

  programs.alacritty.settings.font.size = lib.mkForce 64;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
