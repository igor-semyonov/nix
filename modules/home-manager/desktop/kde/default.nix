{
  config,
  inputs,
  lib,
  nhModules,
  pkgs,
  ...
}: {
  imports = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
    "${nhModules}/misc/wallpaper"
  ];

  home.packages = with pkgs; [
    (catppuccin-kde.override {
      flavour = ["mocha"];
      accents = ["pink"];
    })
    plasmusic-toolbar
    kara
    kde-rounded-corners
    kdePackages.kcalc
    kdePackages.krohnkite
    kdotool
    tela-circle-icon-theme
    papirus-nord
  ];

  # Set gpg agent specific to KDE/Kwallet
  services.gpg-agent = {
    pinentry.package = lib.mkForce pkgs.kwalletcli;
    extraConfig = "pinentry-program ${pkgs.kwalletcli}/bin/pinentry-kwallet";
  };

  programs.plasma = {
    enable = true;

    fonts = {
      fixedWidth = {
        family = "FiraCode Nerd Font Mono";
        pointSize = 14;
      };
      general = {
        family = "Roboto";
        pointSize = 14;
      };
      menu = {
        family = "Roboto";
        pointSize = 14;
      };
      small = {
        family = "Roboto";
        pointSize = 11;
      };
      toolbar = {
        family = "Roboto";
        pointSize = 14;
      };
      windowTitle = {
        family = "Roboto";
        pointSize = 14;
      };
    };

    hotkeys.commands = {
      tts-selection = {
        name = "TTS Selection";
        key = "Ctrl+Meta+C";
        command = "tts-nix-selection";
      };
      launch-alacritty = {
        name = "Launch Alacritty";
        key = "Meta+T";
        command = "alacritty";
      };
      # launch-brave = {
      #   name = "Launch Brave";
      #   key = "Meta+Shift+B";
      #   command = "brave";
      # };
      # launch-ocr = {
      #   name = "Launch OCR";
      #   key = "Alt+@";
      #   command = "ocr";
      # };
      # launch-ulauncher = {
      #   name = "Launch ulauncher";
      #   key = "Ctrl+Space";
      #   command = "ulauncher-toggle";
      # };
      # screenshot-region = {
      #   name = "Capture a rectangular region of the screen";
      #   key = "Meta+Shift+S";
      #   command = "spectacle --region --nonotify";
      # };
      # screenshot-screen = {
      #   name = "Capture the entire desktop";
      #   key = "Meta+Ctrl+S";
      #   command = "spectacle --fullscreen --nonotify";
      # };
    };

    input = {
      keyboard = {
        numlockOnStartup = "on";
        layouts = [
          {
            layout = "en";
          }
        ];
        # repeatDelay = 250;
        # repeatRate = 40;
      };
      mice = [
        # {
        #   accelerationProfile = "none";
        #   name = "Razer Razer Viper V3 Pro";
        #   productId = "00c1";
        #   vendorId = "1532";
        # }
        # {
        #   accelerationProfile = "none";
        #   name = "Logitech USB Receiver";
        #   productId = "c547";
        #   vendorId = "046d";
        # }
      ];
      # touchpads = [
      #   {
      #     disableWhileTyping = true;
      #     enable = true;
      #     leftHanded = false;
      #     middleButtonEmulation = true;
      #     name = "ELAN06A0:00 04F3:3231 Touchpad";
      #     naturalScroll = true;
      #     pointerSpeed = 0;
      #     productId = "3231";
      #     tapToClick = true;
      #     vendorId = "04f3";
      #   }
      # ];
    };

    krunner = {
      activateWhenTypingOnDesktop = true;
      position = "center";
      shortcuts.launch = "Alt+Space";
    };

    kscreenlocker = {
      appearance.wallpaper = "${config.wallpaper}";
      timeout = 10;
      lockOnResume = true;
    };
    configFile.kscreenlockerrc = {
      "Greeter/LnF/General/hideClockWhenIdle" = {value = true;};
      "Greeter/LnF/General/showMediaControls" = {value = false;};
      # Greeter.WallpaperPlugin = "org.kde.potd";
      # To use nested groups use / as a separator. In the below example,
      # Provider will be added to [Greeter][Wallpaper][org.kde.potd][General].
      # "Greeter/Wallpaper/org.kde.potd/General".Provider = "noaa";
      # "Greeter/Wallpaper/org.kde.potd/General".FillMode = 1;
    };

    kwin = {
      effects = {
        blur = {
          enable = false;
          strength = 8;
          noiseStrength = 7;
        };
        cube.enable = false;
        desktopSwitching.animation = "slide";
        dimAdminMode.enable = true;
        dimInactive.enable = false;
        fallApart.enable = false;
        fps.enable = false;
        minimization = {
          animation = "magiclamp";
          duration = 125;
        };
        shakeCursor.enable = true;
        slideBack.enable = false;
        snapHelper.enable = false;
        translucency.enable = true;
        windowOpenClose.animation = "scale";
        wobblyWindows.enable = false;
      };

      nightLight = {
        enable = false;
        # location.latitude = "52.23";
        # location.longitude = "21.01";
        # mode = "location";
        # temperature.night = 4000;
      };

      virtualDesktops = {
        number = 4;
        rows = 2;
      };
    };

    overrideConfig = true;

    desktop.widgets = [
      {
        plasmusicToolbar = {
          position = {
            horizontal = 51;
            vertical = 100;
          };
          size = {
            width = 250;
            height = 250;
          };
        };
      }
    ];

    panels = [
      # Windows-like panel at the bottom
      {
        height = 128;
        location = "left";
        hiding = "none";
        floating = true;
        opacity = "translucent";
        widgets = [
          # We can configure the widgets by adding the name and config
          # attributes. For example to add the the kickoff widget and set the
          # icon to "nix-snowflake-white" use the below configuration. This will
          # add the "icon" key to the "General" group for the widget in
          # ~/.config/plasma-org.kde.plasma.desktop-appletsrc.
          # {
          #   name = "org.kde.plasma.kickoff";
          #   config = {
          #     General = {
          #       icon = "nix-snowflake-white";
          #       alphaSort = true;
          #     };
          #   };
          # }
          # Or you can configure the widgets by adding the widget-specific options for it.
          # See modules/widgets for supported widgets and options for these widgets.
          # For example:
          {
            kickoff = {
              sortAlphabetically = true;
              icon = "nix-snowflake-white";
            };
          }
          # Adding configuration to the widgets can also for example be used to
          # pin apps to the task-manager, which this example illustrates by
          # pinning dolphin and konsole to the task-manager by default with widget-specific options.
          {
            iconTasks = {
              launchers = [
                "applications:firefox.desktop"
              ];
            };
          }
          # Or you can do it manually, for example:
          # {
          #   name = "org.kde.plasma.icontasks";
          #   config = {
          #     General = {
          #       launchers = [
          #         "applications:org.kde.dolphin.desktop"
          #         "applications:org.kde.konsole.desktop"
          #       ];
          #     };
          #   };
          # }
          # If no configuration is needed, specifying only the name of the
          # widget will add them with the default configuration.
          # "org.kde.plasma.marginsseparator"
          # If you need configuration for your widget, instead of specifying the
          # the keys and values directly using the config attribute as shown
          # above, plasma-manager also provides some higher-level interfaces for
          # configuring the widgets. See modules/widgets for supported widgets
          # and options for these widgets. The widgets below shows two examples
          # of usage, one where we add a digital clock, setting 12h time and
          # first day of the week to Sunday and another adding a systray with
          # some modifications in which entries to show.
          {
            panelSpacer = {
              expanding = true;
            };
          }
          {
            digitalClock = {
              calendar.firstDayOfWeek = "sunday";
              time.format = "24h";
            };
          }
          {
            panelSpacer = {
              expanding = true;
            };
          }
          # "org.kde.plasma.marginsseparator"
          {
            systemTray = {
              pin = false;
              icons = {
                spacing = "small";
                scaleToFit = true;
              };
              items = {
                # We explicitly show bluetooth and battery
                shown = [
                ];
                # And explicitly hide networkmanagement and volume
                hidden = [
                  "org.kde.plasma.networkmanagement"
                  "org.kde.plasma.volume"
                  "org.kde.plasma.brightness"
                  "org.kde.plasma.networkManagement"
                  "ord.kde.plasma.clipboard"
                  "org.kde.plasma.battery"
                  "org.kde.plasma.bluetooth"
                  "org.kde.plasma.networkmanagement"
                  "org.kde.plasma.diskquota"
                  "org.kde.plasma.keyboardindicator"
                  "org.kde.plasma.keyboardlayout"
                ];
              };
            };
          }
        ];
      }
      # Application name, Global menu and Song information and playback controls at the top
      # {
      #   location = "top";
      #   height = 26;
      #   widgets = [
      #     {
      #       applicationTitleBar = {
      #         behavior = {
      #           activeTaskSource = "activeTask";
      #         };
      #         layout = {
      #           elements = [ "windowTitle" ];
      #           horizontalAlignment = "left";
      #           showDisabledElements = "deactivated";
      #           verticalAlignment = "center";
      #         };
      #         overrideForMaximized.enable = false;
      #         titleReplacements = [
      #           {
      #             type = "regexp";
      #             originalTitle = "^Brave Web Browser$";
      #             newTitle = "Brave";
      #           }
      #           {
      #             type = "regexp";
      #             originalTitle = ''\\bDolphin\\b'';
      #             newTitle = "File manager";
      #           }
      #         ];
      #         windowTitle = {
      #           font = {
      #             bold = false;
      #             fit = "fixedSize";
      #             size = 12;
      #           };
      #           hideEmptyTitle = true;
      #           margins = {
      #             bottom = 0;
      #             left = 10;
      #             right = 5;
      #             top = 0;
      #           };
      #           source = "appName";
      #         };
      #       };
      #     }
      #     "org.kde.plasma.appmenu"
      #     "org.kde.plasma.panelspacer"
      #     {
      #       plasmusicToolbar = {
      #         panelIcon = {
      #           albumCover = {
      #             useAsIcon = false;
      #             radius = 8;
      #           };
      #           icon = "view-media-track";
      #         };
      #         playbackSource = "auto";
      #         musicControls.showPlaybackControls = true;
      #         songText = {
      #           displayInSeparateLines = true;
      #           maximumWidth = 640;
      #           scrolling = {
      #             behavior = "alwaysScroll";
      #             speed = 3;
      #           };
      #         };
      #       };
      #     }
      #   ];
      # }
    ];

    powerdevil = {
      AC = {
        # autoSuspend.action = "nothing";
        powerButtonAction = "showLogoutScreen";
        dimDisplay.enable = false;
        autoSuspend = {
          action = "nothing";
          # idleTimeout = 36000;
        };
        turnOffDisplay = {
          idleTimeout = 600;
          # idleTimeoutWhenLocked = "immediately";
        };
      };
      # battery = {
      #   powerButtonAction = "sleep";
      #   whenSleepingEnter = "standbyThenHibernate";
      # };
      # lowBattery = {
      #   whenLaptopLidClosed = "hibernate";
      # };
    };

    session = {
      general.askForConfirmationOnLogout = false;
      sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";
    };

    shortcuts = {
      "kwin"."Window Maximize" = "Meta+PgUp";
      "kwin"."Window Close" = "Alt+F4";
      "kwin"."TrackMouse" = "Meta+`,none,Track mouse";
      "kwin"."ClearLastMouseMark" = "Meta+Shift+F12";
      "kwin"."ClearMouseMarks" = "Meta+Shift+F11";
      "kwin"."Grid View" = "Meta+G";
      "kwin"."Invert" = "Meta+Ctrl+I";
      "kwin"."InvertWindow" = ["Ctrl+Alt+I" "Toggle Invert Effect on Window"];
      "kwin"."Kill Window" = "Ctrl+Alt+Esc,Meta+Ctrl+Esc,Kill Window";
      "kwin"."Overview" = "Meta+W";
      "kwin"."Switch One Desktop Down" = "Meta+Ctrl+Down";
      "kwin"."Switch One Desktop Up" = "Meta+Ctrl+Up";
      "kwin"."Switch One Desktop to the Left" = "Meta+Ctrl+Left";
      "kwin"."Switch One Desktop to the Right" = "Meta+Ctrl+Right";
      "kwin"."Switch to Desktop 1" = "Ctrl+F1";
      "kwin"."Switch to Desktop 2" = "Ctrl+F2";
      "kwin"."Switch to Desktop 3" = "Ctrl+F3";
      "kwin"."Switch to Desktop 4" = "Ctrl+F4";
      "kwin"."Walk Through Windows" = ["Alt+Tab" "Alt+Tab,Walk Through Windows"];
      "kwin"."Walk Through Windows (Reverse)" = ["Alt+Shift+Backtab" "Alt+Shift+Tab,Walk Through Windows (Reverse)"];
      "kwin"."Walk Through Windows of Current Application" = ["Meta+Tab" "Alt+`,Walk Through Windows of Current Application"];
      "kwin"."Walk Through Windows of Current Application (Reverse)" = ["Meta+Shift+Tab" "Alt+~,Walk Through Windows of Current Application (Reverse)"];
      "kwin"."Window One Desktop Down" = "Meta+Alt+Down,Meta+Ctrl+Shift+Down,Window One Desktop Down";
      "kwin"."Window One Desktop Up" = "Meta+Alt+Up,Meta+Ctrl+Shift+Up,Window One Desktop Up";
      "kwin"."Window One Desktop to the Left" = "Meta+Alt+Left,Meta+Ctrl+Shift+Left,Window One Desktop to the Left";
      "kwin"."Window One Desktop to the Right" = "Meta+Alt+Right,Meta+Ctrl+Shift+Right,Window One Desktop to the Right";
      "kwin"."Window Quick Tile Bottom" = ["Meta+Down" "Meta+Num+2,Meta+Down,Quick Tile Window to the Bottom"];
      "kwin"."Window Quick Tile Bottom Left" = "Meta+Num+1,,Quick Tile Window to the Bottom Left";
      "kwin"."Window Quick Tile Bottom Right" = "Meta+Num+3,,Quick Tile Window to the Bottom Right";
      "kwin"."Window Quick Tile Left" = ["Meta+Num+4" "Meta+Left,Meta+Left,Quick Tile Window to the Left"];
      "kwin"."Window Quick Tile Right" = ["Meta+Right" "Meta+Num+6,Meta+Right,Quick Tile Window to the Right"];
      "kwin"."Window Quick Tile Top" = ["Meta+Num+8" "Meta+Up,Meta+Up,Quick Tile Window to the Top"];
      "kwin"."Window Quick Tile Top Left" = "Meta+Num+7,,Quick Tile Window to the Top Left";
      "kwin"."Window Quick Tile Top Right" = "Meta+Num+9,,Quick Tile Window to the Top Right";
      "kwin"."Window to Next Screen" = "Meta+Shift+Right";
      "kwin"."Window to Previous Screen" = "Meta+Shift+Left";
      "kwin"."view_actual_size" = ["Meta+Esc" "Zoom to Actual Size"];
      "kwin"."view_zoom_in" = ["Meta+=" "Zoom In"];
      "kwin"."view_zoom_out" = ["Meta+-" "Zoom Out"];
      "kwin"."MoveZoomDown" = "Ctrl+Alt+Down,none,Move Zoomed Area Downwards";
      "kwin"."MoveZoomLeft" = "Ctrl+Alt+Left,none,Move Zoomed Area to Left";
      "kwin"."MoveZoomRight" = "Ctrl+Alt+Right,none,Move Zoomed Area to Right";
      "kwin"."MoveZoomUp" = "Ctrl+Alt+Up,none,Move Zoomed Area Upwards";

      "mediacontrol"."mediavolumedown" = "none,,Media volume down";
      "mediacontrol"."mediavolumeup" = "none,,Media volume up";
      "mediacontrol"."nextmedia" = "Media Next";
      "mediacontrol"."pausemedia" = "Media Pause";
      "mediacontrol"."playmedia" = "none,,Play media playback";
      "mediacontrol"."playpausemedia" = "Media Play";
      "mediacontrol"."previousmedia" = "Media Previous";
      "mediacontrol"."stopmedia" = "Media Stop";
      # kwin = {
      #   "Walk Through Windows of Current Application" = [
      #     "Meta+Tab"
      #     "Alt+`,Walk Through Windows of Current Application"
      #   ];
      #   "Walk Through Windows of Current Application (Reverse)" = [
      #     "Meta+Shift+Tab"
      #     "Alt+~,Walk Through Windows of Current Application (Reverse)"
      #   ];
      # };
      ksmserver = {
        "Lock Session" = [
          "Screensaver"
          "Ctrl+Meta+Alt+L"
        ];
        # "LogOut" = [
        #   "Ctrl+Alt+Q"
        # ];
      };

      # "KDE Keyboard Layout Switcher" = {
      #   "Switch to Next Keyboard Layout" = "Meta+Space";
      # };

      # kwin = {
      #   "KrohnkiteMonocleLayout" = [];
      #   "Overview" = "Meta+A";
      #   "Switch to Desktop 1" = "Meta+1";
      #   "Switch to Desktop 2" = "Meta+2";
      #   "Switch to Desktop 3" = "Meta+3";
      #   "Switch to Desktop 4" = "Meta+4";
      #   "Switch to Desktop 5" = "Meta+5";
      #   "Switch to Desktop 6" = "Meta+6";
      #   "Switch to Desktop 7" = "Meta+7";
      #   "Window Close" = "Meta+Q";
      #   "Window Fullscreen" = "Meta+M";
      #   "Window Move Center" = "Ctrl+Alt+C";
      #   "Window to Desktop 1" = "Meta+!";
      #   "Window to Desktop 2" = "Meta+@";
      #   "Window to Desktop 3" = "Meta+#";
      #   "Window to Desktop 4" = "Meta+$";
      #   "Window to Desktop 5" = "Meta+%";
      #   "Window to Desktop 6" = "Meta+^";
      # };

      # plasmashell = {
      #   "show-on-mouse-pos" = "";
      # };

      # "services/org.kde.dolphin.desktop"."_launch" = "Meta+Shift+F";
    };

    # spectacle = {
    #   shortcuts = {
    #     captureEntireDesktop = "";
    #     captureRectangularRegion = "";
    #     launch = "";
    #     recordRegion = "Meta+Shift+R";
    #     recordScreen = "Meta+Ctrl+R";
    #     recordWindow = "";
    #   };
    # };

    # window-rules = [
    #   {
    #     apply = {
    #       noborder = {
    #         value = true;
    #         apply = "initially";
    #       };
    #     };
    #     description = "Hide titlebar by default";
    #     match = {
    #       window-class = {
    #         value = ".*";
    #         type = "regex";
    #       };
    #     };
    #   }
    #   {
    #     apply = {
    #       desktops = "Desktop_1";
    #       desktopsrule = "3";
    #     };
    #     description = "Assign Brave to Desktop 1";
    #     match = {
    #       window-class = {
    #         value = "brave-browser";
    #         type = "substring";
    #       };
    #       window-types = ["normal"];
    #     };
    #   }
    #   {
    #     apply = {
    #       desktops = "Desktop_2";
    #       desktopsrule = "3";
    #     };
    #     description = "Assign Alacritty to Desktop 2";
    #     match = {
    #       window-class = {
    #         value = "Alacritty";
    #         type = "substring";
    #       };
    #       window-types = ["normal"];
    #     };
    #   }
    # ];

    workspace = {
      enableMiddleClickPaste = false;
      clickItemTo = "select";
      colorScheme = "CatppuccinMochaPink";
      iconTheme = "Papirus-Dark";
      cursor = {
        theme = "Bibata-Original-Amber-Right";
        size = 96;
      };
      splashScreen = {
        engine = "KSplashQML";
        theme = "Catppuccin-Mocha-Pink";
      };
      tooltipDelay = 1;
      wallpaper = "${config.wallpaper}";
    };

    configFile = {
      baloofilerc."Basic Settings"."Indexing-Enabled" = false;
      kdeglobals = {
        General = {
          BrowserApplication = "firefox.desktop";
        };
        KDE = {
          AnimationDurationFactor = 0.5;
        };
      };
      klaunchrc.FeedbackStyle.BusyCursor = false;
      klipperrc.General.MaxClipItems = 1000;
      kwinrc = {
        "TabBox" = {
          "LayoutName" = "compact";
          "ApplicationsMode" = 1;
        };
        "Effect-overview"."BorderActivate" = 9;
        "Effect-mousemark" = {
          "Color" = "0,0,255";
          "LineWidth" = 7;
        };
        "Effect-zoom" = {
          "MouseTracking" = 1;
          "PixelGridZoom" = 25;
        };
        Plugins = {
          krohnkiteEnabled = false;
          mousemarkEnabled = true;
          screenedgeEnabled = false;
          invertEnabled = true;
        };
        # "Round-Corners" = {
        #   ActiveOutlineAlpha = 255;
        #   ActiveOutlineUseCustom = false;
        #   ActiveOutlineUsePalette = true;
        #   ActiveSecondOutlineUseCustom = false;
        #   ActiveSecondOutlineUsePalette = true;
        #   DisableOutlineTile = false;
        #   DisableRoundTile = false;
        #   InactiveCornerRadius = 8;
        #   InactiveOutlineAlpha = 0;
        #   InactiveOutlineUseCustom = false;
        #   InactiveOutlineUsePalette = true;
        #   InactiveSecondOutlineAlpha = 0;
        #   InactiveSecondOutlineThickness = 0;
        #   OutlineThickness = 1;
        #   SecondOutlineThickness = 0;
        #   Size = 8;
        # };
        # "Script-krohnkite" = {
        #   floatingClass = "ulauncher,brave-nngceckbapebfimnlniiiahkandclblb-Default,org.kde.kcalc";
        #   screenGapBetween = 3;
        #   screenGapBottom = 3;
        #   screenGapLeft = 3;
        #   screenGapRight = 3;
        #   screenGapTop = 3;
        # };
        # Windows = {
        #   DelayFocusInterval = 0;
        #   FocusPolicy = "FocusFollowsMouse";
        # };
      };
      plasmanotifyrc = {
        DoNotDisturb.WhenScreenSharing = false;
        Notifications.PopupTimeout = 3000;
      };
      plasmarc.OSD.Enabled = true;
      spectaclerc = {
        Annotations.annotationToolType = 8;
        General = {
          launchAction = "DoNotTakeScreenshot";
          showCaptureInstructions = false;
          showMagnifier = "ShowMagnifierAlways";
          useReleaseToCapture = true;
        };
        ImageSave.imageCompressionQuality = 100;
      };

      "krunnerrc" = {
        "General"."font" = "Roboto,64,-1,5,50,0,0,0,0,0";
        "PlasmaRunnerManager"."migrated" = true;
        "Plugins" = {
          "CharacterRunnerEnabled" = true;
          "DictionaryEnabled" = true;
          "Kill RunnerEnabled" = true;
          "PowerDevilEnabled" = true;
          "Spell CheckerEnabled" = true;
          "appstreamEnabled" = true;
          "baloosearchEnabled" = false;
          "bookmarksEnabled" = false;
          "browserhistoryEnabled" = true;
          "browsertabsEnabled" = true;
          "calculatorEnabled" = true;
          "desktopsessionsEnabled" = false;
          "katesessionsEnabled" = false;
          "konsoleprofilesEnabled" = false;
          "ktp_contactsEnabled" = true;
          "kwinEnabled" = true;
          "locationsEnabled" = true;
          "marbleEnabled" = true;
          "org.kde.activities2Enabled" = false;
          "org.kde.activitiesEnabled" = false;
          "org.kde.datetimeEnabled" = true;
          "org.kde.windowedwidgetsEnabled" = true;
          "placesEnabled" = true;
          "plasma-desktopEnabled" = true;
          "recentdocumentsEnabled" = true;
          "servicesEnabled" = true;
          "shellEnabled" = false;
          "unitconverterEnabled" = true;
          "webshortcutsEnabled" = false;
          "windowsEnabled" = false;
        };
      };
    };
    dataFile = {
      "dolphin/view_properties/global/.directory"."Dolphin"."ViewMode" = 1;
      "dolphin/view_properties/global/.directory"."Settings"."HiddenFilesShown" = true;
    };

    # startup.startupScript = {
    #   ulauncher = {
    #     text = "ulauncher --hide-window";
    #     priority = 8;
    #     runAlways = true;
    #   };
    # };
  };
}
