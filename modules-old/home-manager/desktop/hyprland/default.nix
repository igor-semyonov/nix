{
  config,
  lib,
  nhModules,
  pkgs,
  ...
}: let
  zoom-py = pkgs.writers.writePython3 "zoom-py" {
    flakeIgnore = ["E501" "W191"]; # Add "E501" to ignore line length errors
  } (builtins.readFile ./zoom.py);
in {
  imports = [
    # "${nhModules}/misc/wallpaper"
    # "${nhModules}/programs/swappy"
    # "${nhModules}/programs/wofi"
    # "${nhModules}/services/cliphist"
    # "${nhModules}/services/kanshi"
    # "${nhModules}/services/swaync"
    "${nhModules}/services/waybar"
    "${nhModules}/programs/anyrun"
  ];

  # Consistent cursor theme across all applications.
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Original-Amber-Right";
    size = 96;
  };

  # Source hyprland config from the home-manager store
  xdg.configFile = {
    # "hypr/hyprland.conf" = {
    #   source = ./hyprland.conf;
    # };
    "hypr/shaders/invert.frag" = {
      source = ./invert.frag;
    };

    # "hypr/hyprpaper.conf".text = ''
    #   splash = false
    #   preload = ${config.wallpaper}
    #   wallpaper = DP-1, ${config.wallpaper}
    #   wallpaper = eDP-1, ${config.wallpaper}
    # '';

    # "hypr/hypridle.conf".text = ''
    #   general {
    #     lock_cmd = pidof hyprlock || hyprlock
    #     before_sleep_cmd = loginctl lock-session
    #     after_sleep_cmd = hyprctl dispatch dpms on
    #   }
    # '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # use the version from the nixos module
    portalPackage = null;

    settings = {
      # Load wallpapers
      exec-once = [
        "hyprpaper"
        # Execute your favorite apps at launch
        "hypridle"
        "gnome-keyring-daemon --start --components=secrets"
        # exec-once = kanshi
        " nm-applet --indicator"
        "swaync"
        # "ulauncher --hide-window"
        # "waybar"
        # "wl-paste --watch cliphist store"
        # "wlsunset -l 52.23 -L 21.01"
      ];

      # Monitor settings
      monitor = [",preferred,0x0,1"];

      # Input device setting
      input = {
        kb_layout = "us";
        kb_variant = "";
        kb_model = "";
        kb_options = "";
        kb_rules = "";
        numlock_by_default = true;

        follow_mouse = 2;
        # mouse_refocus = false;

        touchpad = {
          natural_scroll = false;
        };

        sensitivity = 5;
        accel_profile = "flat";
      };

      # General settings
      general = {
        allow_tearing = "true";
        border_size = 8;
        # "col.active_border" = "rgb(b7bdf8)";
        "col.active_border" = "rgba(80ff80ff) rgba(ff80ffff) 45deg";
        "col.inactive_border" = "rgba(802020ff) rgba(202080ff) 135deg";
        gaps_in = 3;
        gaps_out = 3;

        layout = "master";
        # layout = "dwindle";

        gaps_workspaces = 32;

        resize_on_border = false;
        hover_icon_on_border = false;

        resize_corner = 3;
      };

      # Window decorations settings
      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
      };

      # Animations settings
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
          "zoomFactor, 1, 1, default"
        ];
      };

      # Layouts settings
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        orientation = "left";
        mfact = "0.50";
      };

      # Mouse gestures settings
      # gestures = {
      #   workspace_swipe = "false";
      # };

      binds = {
        scroll_event_delay = 0;
      };

      # Misc settings
      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = false;
        disable_splash_rendering = false;
        vrr = 0;
      };

      debug = {
        overlay = false;
        disable_logs = true;
      };

      # device {
      #   name = epic-mouse-v1
      #   sensitivity = -0.5
      # }

      # Window rules
      # Center specific windows
      # windowrule = [
      #   "center 1, class:^(.blueman-manager-wrapped)$"
      #   "windowrule = center 1, class:^(gnome-calculator|org\.gnome\.Calculator)$"
      #   "windowrule = center 1, class:^(nm-connection-editor)$"
      #   "windowrule = center 1, class:^(org.pulseaudio.pavucontrol)$"
      #   "windowrule = center 1, initialTitle:^(Study Deck)$"
      #   "windowrule = center 1, initialTitle:^(_crx_.*)$"

      #   # Float specific windows
      #   "float, class:^(.blueman-manager-wrapped)$"
      #   "float, class:^(gnome-calculator|org\.gnome\.Calculator)$"
      #   "float, class:^(nm-connection-editor)$"
      #   "float, class:^(org.pulseaudio.pavucontrol)$"
      #   "float, class:^(ulauncher)$"
      #   "float, initialTitle:^(_crx_.*)$"
      #   "float, title:^(MainPicker)$"

      #   # Remove border for specific applications
      #   "noborder, class:^(ulauncher)$"
      #   "noborder, title:^(.*is sharing (your screen|a window)\.)$"

      #   # Set size for specific windows
      #   "size 50%, class:^(.blueman-manager-wrapped)$"
      #   "size 50%, class:^(nm-connection-editor)$"
      #   "size 50%, class:^(org.pulseaudio.pavucontrol)$"

      #   # Keep focus on specific windows when they open
      #   "stayfocused, class:^(.blueman-manager-wrapped)$"
      #   "stayfocused, class:^(gnome-calculator|org\.gnome\.Calculator)$"
      #   "stayfocused, class:^(org.pulseaudio.pavucontrol)$"
      #   "stayfocused, class:^(swappy)$"
      #   "stayfocused, class:^(ulauncher)$"

      #   # Assign applications to specific workspaces
      #   "workspace 1, class:^(brave-browser)$"
      #   "workspace 2, class:^(Alacritty)$"
      #   "workspace 3, class:^(org\.telegram\.desktop)$"
      #   "workspace 4, class:^(com\.obsproject\.Studio)$"
      #   "workspace 4, class:^(steam)$"
      #   "workspace 5 silent, class:^(zoom)$"
      #   "workspace 5, class:^(steam_app_\d+)$"
      #   "workspace special silent, title:^(.*is sharing (your screen|a window)\.)$"
      #   "workspace special, class:^(gnome-pomodoro)$"

      #   # Show applications on all workspaces (pin)
      #   "pin, title:^(as_toolbar)$"
      # ];

      cursor = {
        zoom_rigid = true;
        zoom_detached_camera = false;
        hide_on_key_press = true;
      };

      # Bindings
      "$mainmod" = "SUPER";
      bind = [
        "SUPER CTRL ALT, Q, exec, hyprctl dispatch exit"
        "$mainmod, T, exec, alacritty"
        "$mainmod, space, exec, anyrun"
        "CTRL ALT, P, exec, gnome-pomodoro --start-stop"

        ''$mainmod CTRL, L, exec, hyprctl keyword general:layout "$(hyprctl getoption general:layout | grep -q 'dwindle' && echo 'master' || echo 'dwindle')"''

        "$mainmod, n, layoutmsg, swapwithmaster"

        "CTRL $mainmod, mouse_up, exec, ${zoom-py} out 0.25"
        "CTRL $mainmod, mouse_down, exec, ${zoom-py} in 0.25"
        "$mainmod, minus, exec, ${zoom-py} out 0.5"
        "$mainmod, equal, exec, ${zoom-py} in 0.5"
        "$mainmod, escape, exec, ${zoom-py} out 100"
        "Ctrl Alt, I, exec, hyprctl getoption decoration:screen_shader |grep invert && hyprctl keyword decoration:screen_shader || hyprctl keyword decoration:screen_shader ~/.config/hypr/shaders/invert.frag"
        "CTRL SUPER, C, exec, tts-selection"
        "$mainmod SHIFT, Return, exec, alacritty"
        "$mainmod SHIFT, Return, exec, alacritty"
        # "$mainmod SHIFT, B, exec, brave"
        # "$mainmod SHIFT, F, exec, nautilus"

        "$mainmod, Return, layoutmsg, swapwithmaster"
        "$mainmod, R, layoutmsg, orientationcycle"
        "$mainmod, Q, killactive,"
        "CTRL ALT, Q, exit"
        "$mainmod, F, togglefloating"
        "$mainmod, M, fullscreen"
        "$mainmod SHIFT, M, movetoworkspacesilent, special"
        "$mainmod SHIFT, P, togglespecialworkspace"
        "$mainmod SHIFT, C, exec, hyprpicker -a"

        # Move focus with mainmod + arrow keys
        "$mainmod, l, movefocus, r"
        "$mainmod, h, movefocus, l"
        "$mainmod, k, movefocus, u"
        "$mainmod, j, movefocus, d"

        # Resize windows
        "$mainmod SHIFT, h, resizeactive, -50 0"
        "$mainmod SHIFT, l, resizeactive, 50 0"
        "$mainmod SHIFT, k, resizeactive, 0 -50"
        "$mainmod SHIFT, j, resizeactive, 0 50"

        # Switch workspaces with mainmod + [0-9]
        "$mainmod, 1, workspace, 1"
        "$mainmod, 2, workspace, 2"
        "$mainmod, 3, workspace, 3"
        "$mainmod, 4, workspace, 4"
        "$mainmod, 5, workspace, 5"
        "$mainmod, 6, workspace, 6"
        "$mainmod, 7, workspace, 7"
        "$mainmod, 8, workspace, 8"
        "$mainmod, 9, workspace, 9"
        "$mainmod, 0, workspace, 10"

        # Move active window to a workspace with mainmod + SHIFT + [0-9]
        "$mainmod SHIFT, 1, movetoworkspace, 1"
        "$mainmod SHIFT, 2, movetoworkspace, 2"
        "$mainmod SHIFT, 3, movetoworkspace, 3"
        "$mainmod SHIFT, 4, movetoworkspace, 4"
        "$mainmod SHIFT, 5, movetoworkspace, 5"
        "$mainmod SHIFT, 6, movetoworkspace, 6"
        "$mainmod SHIFT, 7, movetoworkspace, 7"
        "$mainmod SHIFT, 8, movetoworkspace, 8"
        "$mainmod SHIFT, 9, movetoworkspace, 9"
        "$mainmod SHIFT, 0, movetoworkspace, 10"

        # Scroll through existing workspaces with mainmod + scroll
        # "$mainmod, mouse_down, workspace, e+1"
        # "$mainmod, mouse_up, workspace, e-1"

        # Application menu
        "$mainmod, A, exec, wofi --show drun --allow-images"

        # Center focused window
        "CTRL ALT, C, centerwindow"

        # Clipboard
        "ALT SHIFT, V, exec, cliphist list | wofi --show dmenu | cliphist decode | wl-copy"

        # Ulauncher
        "CTRL, Space, exec, ulauncher-toggle"

        # Screenshot area
        "$mainmod SHIFT, S, exec, $HOME/.local/bin/hyprshot --freeze --silent --raw --mode region | swappy -f -"

        # Screenshot entire screen
        "$mainmod CTRL, S, exec, $HOME/.local/bin/hyprshot --freeze --silent --raw --mode output | swappy -f -"

        # Screen recording
        "$mainmod SHIFT, R, exec, $HOME/.local/bin/screen-recorder"

        # OCR
        "ALT SHIFT, 2, exec, $HOME/.local/bin/ocr"

        # Lock screen
        "SUPER CTRL ALT, L, exec, hyprlock"

        # Adjust brightness
        # ", XF86MonBrightnessUp, exec, brightnessctl set +10%"
        # ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"

        # Open notifications
        "$mainmod, V, exec, swaync-client -t -sw"

        # Adjust  volume
        ", XF86AudioRaiseVolume, exec, pamixer --increase 10"
        ", XF86AudioLowerVolume, exec, pamixer --decrease 10"
        ", XF86AudioMute, exec, pamixer --toggle-mute"
        ", XF86AudioMicMute, exec, pamixer --default-source --toggle-mute"

        # Adjust mic sensitivity
        "SHIFT, XF86AudioRaiseVolume, exec, pamixer --increase 10 --default-source"
        "SHIFT, XF86AudioLowerVolume, exec, pamixer --decrease 10 --default-source"

        # Adjust keyboard backlight
        # "SHIFT, XF86MonBrightnessUp, exec, brightnessctl -d tpacpi::kbd_backlight set +33%"
        # "SHIFT, XF86MonBrightnessDown, exec, brightnessctl -d tpacpi::kbd_backlight set 33%-"
      ];

      bindm = [
        # Move/resize windows with mainmod + LMB/RMB and dragging
        "$mainmod, mouse:272, movewindow"
        "$mainmod, mouse:273, resizewindow"
      ];
    };
    extraConfig = ''
    '';
  };

  programs = {
    hyprlock = {
      enable = true;
      # package = pkgs.hyprlock;
      settings = {
        "$font" = "FiraCode";

        general = {
          hide_cursor = true;
          grace = 2;
          fail_timeout = 500;
        };

        animations = {
          enabled = true;
          bezier = "linear, 1, 1, 0, 0";
          animation = [
            "fadeIn, 1, 5, linear"
            "fadeOut, 1, 5, linear"
            "inputFieldDots, 1, 2, linear"
          ];
        };

        background = {
          monitor = "";
          path = "screenshot";
          blur_passes = 3;
        };

        input-field = {
          monitor = "";
          size = "20%, 5%";
          outline_thickness = 3;
          inner_color = "rgba(0, 0, 0, 0.0) # no fill";

          outer_color = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          check_color = "rgba(00ff99ee) rgba(ff6633ee) 120deg";
          fail_color = "rgba(ff6633ee) rgba(ff0066ee) 40deg";

          font_color = "rgb(143, 143, 143)";
          fade_on_empty = false;
          rounding = 15;

          font_family = "$font";
          placeholder_text = "Input password...";
          fail_text = "$PAMFAIL";

          # uncomment to use a letter instead of a dot to indicate the typed password
          # dots_text_format = *
          # dots_size = 0.4
          dots_spacing = 0.3;

          # uncomment to use an input indicator that does not show the password length (similar to swaylock's input indicator)
          # hide_input = true

          position = "0, -20";
          halign = "center";
          valign = "center";
        };

        label = [
          # TIME
          {
            monitor = "";
            text = "$TIME # ref. https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/#variable-substitution";
            font_size = 256;
            font_family = "$font";

            position = "0, -50px";
            halign = "center";
            valign = "top";
          }
          # DATE
          {
            monitor = "";
            text = ''cmd[update:60000] date +"%A, %d %B %Y" # update every 60 seconds'';
            font_size = 96;
            font_family = "$font";

            position = "0, 50";
            halign = "center";
            valign = "bottom";
          }
        ];

        # keyboard layout
        # label {
        #     monitor =
        #     text = $LAYOUT[en,ru]
        #     font_size = 24
        #     onclick = hyprctl switchxkblayout all next

        #     position = 250, -20
        #     halign = center
        #     valign = center
        # }
      };
    };
  };

  # dconf.settings = {
  #   "org/blueman/general" = {
  #     "plugin-list" = lib.mkForce ["!StatusNotifierItem"];
  #   };

  #   "org/blueman/plugins/powermanager" = {
  #     "auto-power-on" = true;
  #   };

  #   "org/gnome/calculator" = {
  #     "accuracy" = 9;
  #     "angle-units" = "degrees";
  #     "base" = 10;
  #     "button-mode" = "basic";
  #     "number-format" = "automatic";
  #     "show-thousands" = false;
  #     "show-zeroes" = false;
  #     "source-currency" = "";
  #     "source-units" = "degree";
  #     "target-currency" = "";
  #     "target-units" = "radian";
  #     "window-maximized" = false;
  #   };

  #   "org/gnome/desktop/interface" = {
  #     "color-scheme" = "prefer-dark";
  #     "cursor-theme" = "Bibata-Original-Amber-Right";
  #     "font-name" = "Roboto 14";
  #     "icon-theme" = "Papirus-Dark";
  #   };

  #   "org/gnome/desktop/wm/preferences" = {
  #     "button-layout" = lib.mkForce "";
  #   };

  #   "org/gnome/nautilus/preferences" = {
  #     "default-folder-viewer" = "list-view";
  #     "migrated-gtk-settings" = true;
  #     "search-filter-time-type" = "last_modified";
  #     "search-view" = "list-view";
  #   };

  #   "org/gnome/nm-applet" = {
  #     "disable-connected-notifications" = true;
  #     "disable-vpn-notifications" = true;
  #   };

  #   "org/gtk/gtk4/settings/file-chooser" = {
  #     "show-hidden" = true;
  #   };

  #   "org/gtk/settings/file-chooser" = {
  #     "date-format" = "regular";
  #     "location-mode" = "path-bar";
  #     "show-hidden" = true;
  #     "show-size-column" = true;
  #     "show-type-column" = true;
  #     "sort-column" = "name";
  #     "sort-directories-first" = false;
  #     "sort-order" = "ascending";
  #     "type-format" = "category";
  #     "view-type" = "list";
  #   };
  # };
}
