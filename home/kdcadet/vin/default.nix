{nhModules, ...}: {
  imports = [
    # ../programs/alacritty
    ../programs/bash
    ../programs/bat
    # ../programs/matplotlib
    ../programs/fastfetch
    ../programs/gpg
    ../programs/ssh
    ../programs/starship
    ../programs/tmux
  ];

  # Enable home-manager
  programs.home-manager.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
