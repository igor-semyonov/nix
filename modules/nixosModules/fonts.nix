{...}: {
  flake.nixosModules.fonts = {pkgs, ...}: {
    fonts = {
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        nerd-fonts.meslo-lg
        nerd-fonts.fira-code
        roboto
        liberation_ttf
        lato
        fira
        garamond-libre
        eb-garamond
        libertine
        helvetica-neue-lt-std
        noto-fonts-color-emoji
        noto-fonts-monochrome-emoji
        noto-fonts-emoji-blob-bin
        openmoji-color
        openmoji-black
      ];
      fontconfig = {
        enable = true;
        defaultFonts = {
          sansSerif = ["Roboto"];
          serif = ["EB Garamond"];
          monospace = ["FiraCode Nerd Font"];
          emoji = ["Noto Color Emoji" "Openmoji Color"];
        };
        cache32Bit = true;
      };
      fontDir.enable = true;
    };
  };
}
