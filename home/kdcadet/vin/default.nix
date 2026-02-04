{
  inputs,
  pkgs,
nhModules,
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
    };
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
