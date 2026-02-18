{pkgs, ...}: {
  programs.kitty = let
    kitty = pkgs.kitty.overrideAttrs (oldAttrs: {
      desktopItem = oldAttrs.desktopItem.override {
        exec = "${oldAttrs.desktopItem.exec} --start-as fullscreen";
      };
    });
  in {
    enable = true;
    # package = kitty;
    enableGitIntegration = true;
    font = {
      name = "FiraCode Nerd Font";
      package = pkgs.nerd-fonts.fira-code;
      size = 42;
    };
    keybindings = {
      "ctrl+c" = "copy_or_interrupt";
      # "ctrl+f>2" = "set_font_size 20";
    };
    mouseBindings = {
      "ctrl+left click" = "ungrabbed mouse_handle_click selection link prompt";
      "left click" = "ungrabbed no-op";
    };
    quickAccessTerminalConfig = {
      start_as_hidden = false;
      hide_on_focus_loss = true;
      background_opacity = 0.85;
    };
    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;
      repaint_delay = 4;

      cursor_shape = "block";

      hide_window_decorations = true;
    };

    extraConfig = ''
      # For newer Kitty versions, this might work:
      # os_window_state fullscreen
    '';
    shellIntegration.enableBashIntegration = true;
    themeFile = "3024_Night";
  };
}
