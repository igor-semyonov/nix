{
  inputs,
  pkgs,
  nhModules,
  userConfig,
  ...
}: {
  imports = [
    # "${nhModules}/programs/alacritty"
    "${nhModules}/programs/bash"
    "${nhModules}/programs/bat"
    # "${nhModules}/programs/matplotlib"
    "${nhModules}/programs/fastfetch"
    "${nhModules}/programs/gpg"
    "${nhModules}/programs/ssh"
    "${nhModules}/programs/starship"
    "${nhModules}/programs/tmux"
  ];

  home = {
    username = "${userConfig.name}";
    homeDirectory =
      if pkgs.stdenv.isDarwin
      then "/Users/${userConfig.name}"
      else "/home/${userConfig.name}";
    packages = [
      inputs.my-nvim.packages.${pkgs.system}.nvim-nixcats
      pkgs.alacritty
      pkgs.gnumake
      pkgs.git
    ];
    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
      SYSTEMD_EDITOR = "vim";
      TERM=xterm-256color
    };
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
