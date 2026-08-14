{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.stylix = {pkgs, ...}: {
    imports = [inputs.stylix.nixosModules.stylix];

    programs.dconf.enable = true;
    stylix = {
      enable = true;

      # Stylix REQUIRES a wallpaper to build successfully.
      # It normally extracts colors from the image, but we are overriding them below.
      # You can change this to point to a local file: image = ./path/to/wallpaper.png;
      image = "${self}/assets/wallpaper.jpg";

      # Force dark mode metrics across all generated themes
      polarity = "dark";
      base16Scheme = "${self}/modules/stylix/colors.yaml";

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Original-Amber-Right";
        size = 96;
      };

      fonts = {
        sansSerif = {
          package = pkgs.roboto;
          name = "Roboto";
        };

        monospace = {
          # Use the modern Nixpkgs format for Nerd Fonts
          package = pkgs.nerd-fonts.fira-code;
          name = "FiraCode Nerd Font Mono";
        };

        serif = {
          package = pkgs.eb-garamond;
          name = "EB Garamond";
        };

        sizes = {
          applications = 14;
          desktop = 16;
          popups = 24;
          terminal = 48;
        };
      };

      icons = {
        enable = true;

        # probably best coverage and most reasonable while having good contrast
        # package = pkgs.kora-icon-theme;
        # dark = "kora";
        # light = "kora-light";

        # cyberpunk neon
        package = pkgs.candy-icons;
        dark = "candy-icons";
        light = "candy-icons";

        # garuda dragonized used this
        # package = pkgs.beauty-line-icon-theme;
        # dark = "BeautyLine";
        # light = "BeautyLine";
      };

      targets.grub.useWallpaper = false;
    };
  };
}
