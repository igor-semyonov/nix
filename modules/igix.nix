{self, ...}: {
  flake = {
    nixosModules.igix-desktop = {
      imports = with self.nixosModules; [
        common-desktop
        kde
        nix-ld
      ];
    };
    homeModules.igix-desktop = {
      imports = with self.homeModules; [
        common-desktop

        alacritty
        kitty
        bash
        bat
        vivaldi
        brave
        firefox
        matplotlib
        fastfetch
        gpg
        ssh
        starship
        tmux
        xresources
        rustfmt
        clang-format
        btop
        fzf
        mpv
        git
        claude-code

        kde

        tts
        qt
        gtk
        xdg
        flatpak
        easyeffects
      ];
    };
  };
}
