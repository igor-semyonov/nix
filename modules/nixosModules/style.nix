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

      # The Custom High-Contrast Cyberpunk Palette
      base16Scheme = {
        base00 = "000000"; # Pure Pitch Black (Main Background)
        base01 = "0a0a0a"; # Very Dark Grey (Panels, Alt Backgrounds)
        base02 = "ff9000"; # Dark Grey (Selections, Highlights)
        base03 = "333333"; # Grey (Comments, Inactive elements)
        base04 = "cccccc"; # Light Grey (Dark Text)
        base05 = "ffffff"; # Pure White (Main Text - Maximum Contrast)
        base06 = "f5f5f5"; # Off White (Light Text)
        base07 = "ffffff"; # Pure White (Light Background - rarely used)

        base08 = "ff0055"; # Neon Pink/Red (Errors/Alerts)
        base09 = "ff7700"; # Neon Orange (Warnings, secondary accents)
        base0A = "ffee00"; # Neon Yellow (Search matches, warnings)
        base0B = "00ffcc"; # Neon Cyan/Green (Strings, success)
        base0C = "00ccff"; # Neon Cyan/Blue (Regex, escapes)
        base0D = "aa00ff"; # Neon Purple (Primary Accent / Focus rings)
        base0E = "dd00ff"; # Magenta (Keywords)
        base0F = "ff00aa"; # Deep Pink (Deprecated/Misc)
      };

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

      iconTheme = {
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

      targets.grub.useImage = false;
    };
  };
}
