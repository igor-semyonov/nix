{
  inputs,
  self,
  ...
}: {
  flake.homeModules.common = {pkgs, ...}: {
    # imports = [
    #   ../misc/qt
    #   ../misc/gtk
    #   ../misc/xdg
    #   ../programs/alacritty
    #   ../programs/kitty
    #   ../programs/bash
    #   ../programs/bat
    #   ../programs/vivaldi
    #   ../programs/brave
    #   ../programs/firefox
    #   ../programs/matplotlib
    #   # ../programs/btop
    #   ../programs/fastfetch
    #   # ../programs/fzf
    #   # ../programs/git
    #   # ../programs/go
    #   ../programs/gpg
    #   ../programs/ssh
    #   # ../programs/k9s
    #   # ../programs/krew
    #   # ../programs/lazygit
    #   # ../programs/neovim
    #   # ../programs/obs-studio
    #   # ../programs/saml2aws
    #   ../programs/starship
    #   # ../programs/telegram
    #   ../programs/tmux
    #   # ../programs/ulauncher
    #   # ../programs/zsh
    #   # ../programs/zoxide
    #   # ../scripts
    #   ../services/flatpak
    #   ../services/xresources
    #   ../programs/rustfmt
    #   ../programs/clang-format
    #   ../programs/easyeffects
    # ];

    # Nixpkgs configuration
    nixpkgs = {
      overlays = [
        self.overlays.stable-packages
        inputs.nur.overlays.default
      ];
      config.allowUnfree = true;
    };

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";

    # Home-Manager configuration for the user's home environment
    home = {
      # username = "${userConfig.name}";
      # homeDirectory =
      # if pkgs.stdenv.isDarwin
      # then "/Users/${userConfig.name}"
      # else "/home/${userConfig.name}";
    };

    # Ensure common packages are installed
    home.packages = with pkgs;
      [
        bibata-cursors
        papirus-nord
        anki-bin
        awscli2
        dig
        dust
        eza
        fd
        jq
        kubectl
        lazydocker
        nh
        openconnect
        pipenv
        python3
        ripgrep
        # terraform
      ]
      ++ lib.optionals stdenv.isDarwin [
        colima
        docker
        hidden-bar
        raycast
      ]
      ++ lib.optionals (!stdenv.isDarwin) [
        pavucontrol
        tesseract
        unzip
      ];
  };
}
