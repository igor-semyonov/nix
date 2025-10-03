{pkgs, ...}: {
  # Install alacritty via home-manager module
  programs.alacritty = {
    enable = true;
    settings = {
      general = {
        live_config_reload = true;
      };

      terminal = {
        shell.program = "bash";
        shell.args = [
          # "-l"
          # "-c"
          # "tmux attach || tmux "
        ];
      };

      env = {
        # TERM = "xterm-256color";
        TERM = "alacritty";
      };

      window = {
        title = "Alacritty";
        decorations =
          if pkgs.stdenv.isDarwin
          then "buttonless"
          else "none";
        dynamic_title = false;
        dynamic_padding = false;
        dimensions = {
          columns = 80;
          lines = 15;
        };
        startup_mode = "Fullscreen";
        padding = {
          x = 0;
          y = 0;
        };
      };

      scrolling = {
        history = 50000;
        multiplier = 1;
      };

      font = {
        size =
          if pkgs.stdenv.isDarwin
          then 36
          else 41.5;
        normal = {
          family = "FiraCode Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "FiraCode Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "FiraCode Nerd Font";
          style = "Italic";
        };
        bold_italic = {
          family = "FiraCode Nerd Font";
          style = "Bold";
        };
      };

      mouse.hide_when_typing = true;

      selection = {
        semantic_escape_chars = '',│`|:"' ()[]{}<>'';
        save_to_clipboard = true;
      };

      colors = {
        draw_bold_text_with_bright_colors = true;
        primary = {
          background = "#000000";
          bright_foreground = "#eeeeee";
          foreground = "#bdbdbd";
        };
        normal = {
          black = "#323437";
          blue = "#80a0ff";
          cyan = "#79dac8";
          green = "#8cc85f";
          magenta = "#cf87e8";
          red = "#ff5454";
          white = "#c6c6c6";
          yellow = "#e3c78a";
        };
        bright = {
          black = "#949494";
          blue = "#74b2ff";
          cyan = "#85dc85";
          green = "#36c692";
          magenta = "#ae81ff";
          red = "#ff5189";
          white = "#e4e4e4";
          yellow = "#c2c292";
        };
        cursor = {
          # cursor = "#9e9e9e";
          cursor = "#FF20FF";
          text = "#080808";
        };
        selection = {
          background = "#ff9000";
          text = "#080808";
        };
      };

      cursor.unfocused_hollow = false;

      keyboard.bindings = [
        {
          action = "ToggleFullscreen";
          key = "F";
          mods = "Control|Shift";
        }
      ];
    };
  };

  # Enable catppuccin theming for alacritty.
  # catppuccin.alacritty.enable = true;
}
