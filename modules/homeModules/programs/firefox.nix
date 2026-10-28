{...}: {
  flake.homeModules.firefox = {
    pkgs,
    lib,
    config,
    options,
    ...
  }: let
    cfg = config.igix.firefox;
    firefox = config.programs.firefox.finalPackage;
    accent = "#ff6a00";

    # Everything but identity, so a second profile is the same browser with separate
    # logins, cookies and history.
    shared-profile = {
      settings = {
        # "gfx.wayland.hdr" = true;
        # Hardware video decode. Safe across vendors -- the driver
        # choice is made by LIBVA_DRIVER_NAME in the NixOS module, and
        # Firefox falls back to software if VA-API cannot initialise.
        # Note this is decode only: it does nothing for a codec the
        # browser refuses outright, such as 10-bit AV1 over MSE.
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.enabled" = true;
        "media.rdd-ffmpeg.enabled" = true;
        "browser.startup.homepage" = "https://google.com";
        "browser.search.defaultenginename" = "google";
        "browser.search.order.1" = "google";
      };
      search = {
        force = true;
        default = "google";
        order = ["google"];
        engines = {
          "Nix Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "type";
                    value = "packages";
                  }
                  {
                    name = "channel";
                    value = "unstable";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["np"];
          };
          "Nix Options" = {
            urls = [
              {
                template = "https://search.nixos.org/options";
                params = [
                  {
                    name = "type";
                    value = "options";
                  }
                  {
                    name = "channel";
                    value = "unstable";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["no"];
          };
          "Nix Lib" = {
            urls = [
              {
                template = "https://noogle.dev/q?";
                params = [
                  {
                    name = "term";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["nl"];
          };
          "NixOS Wiki" = {
            urls = [{template = "https://nixos.wiki/index.php?search={searchTerms}";}];
            icon = "https://nixos.wiki/favicon.png";
            updateInterval = 24 * 60 * 60 * 1000; # every day
            definedAliases = ["nw"];
          };
          "Home Manager Options" = {
            urls = [{template = "https://home-manager-options.extranix.com/?query={searchTerms}&release=master";}];
            definedAliases = ["hmo"];
          };
          "Youtube" = {
            urls = [{template = "https://www.youtube.com/results?search_query={searchTerms}";}];
            definedAliases = ["y"];
          };
          "Youtube Subscriptions" = {
            urls = [{template = "https://www.youtube.com/feed/subscriptions";}];
            definedAliases = ["ys"];
          };
          "Amazon" = {
            urls = [{template = "https://www.amazon.com/s?k={searchTerms}";}];
            # icon = "https://www.amazon.com/favicon.png";
            definedAliases = ["am"];
          };
          "Amazon Orders" = {
            urls = [{template = "https://www.amazon.com/your-orders/search/ref=ppx_yo2ov_dt_b_search?opt=ab&search={searchTerms}";}];
            definedAliases = ["ao"];
          };
          "Audible" = {
            urls = [{template = "https://www.audible.com/search?keywords={searchTerms}";}];
            definedAliases = ["au"];
          };
          "google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
          "Rust Std" = {
            urls = [{template = "https://doc.rust-lang.org/stable/std/index.html?search={searchTerms}";}];
            definedAliases = ["rs"];
          };
          "Docs.rs" = {
            urls = [{template = "https://docs.rs/releases/search?query={searchTerms}";}];
            definedAliases = ["rc"];
          };
        };
      };
      extensions = {
        packages = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          bitwarden
          darkreader
          vimium
        ];
        settings = {
        };
      };
    };

    # The stock icon with an accent badge, so the two launchers differ at panel size.
    personal-icon = pkgs.runCommand "firefox-personal.png" {nativeBuildInputs = [pkgs.imagemagick];} ''
      magick ${firefox}/share/icons/hicolor/128x128/apps/firefox.png \
        -fill '${accent}' -stroke white -strokewidth 6 -draw 'circle 100,100 100,73' \
        $out
    '';
  in {
    options.igix.firefox.personalProfile.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        A second Firefox profile, `personal`, beside `default`, with its own launcher and an
        orange toolbar and frame so it cannot be mistaken for the default profile. Meant for
        work machines, where `default` is the work identity.
      '';
    };

    config = lib.mkMerge [
      # Stylix reaches home-manager through its NixOS module, so the option does
      # not exist on darwin, where there is no NixOS layer to pull it in. A plain
      # mkIf would still declare `stylix` and fail identically, so the attribute
      # itself has to be absent. Keyed on the option existing rather than on the
      # platform, so a standalone home-manager config without stylix works too.
      #
      # `personal` is left out on purpose: the stock theme under the orange CSS is part of
      # what sets it apart.
      (lib.optionalAttrs (options ? stylix) {
        stylix.targets.firefox.profileNames = ["default"];
      })
      {
        services.psd = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          enable = true;
          resyncTimer = "1h";
        };
        # overlayfs is more complicated with btrfs and I have plenty of ram. Choosing not to use overlayfs, maybe for leto it would make sense.
        # xdg.configFile."psd/psd.conf".text = ''
        #   USE_OVERLAYFS="yes"
        # '';

        programs.firefox = {
          enable = true;
          configPath = ".mozilla/firefox";
          profiles.default = lib.mkMerge [
            shared-profile
            {
              id = 0;
              name = "default";
              isDefault = true;
            }
          ];
        };
      }
      (lib.mkIf cfg.personalProfile.enable (lib.mkMerge [
        {
          programs.firefox.profiles.personal = lib.mkMerge [
            shared-profile
            {
              id = 1;
              name = "personal";
              settings."toolkit.legacyUserProfileCustomizations.stylesheets" = true;
              userChrome = ''
                #navigator-toolbox,
                #TabsToolbar,
                #nav-bar,
                #PersonalToolbar {
                  background: ${accent} !important;
                  color: black !important;
                }
                .tabbrowser-tab:not([selected]) .tab-label {
                  color: black !important;
                }
                #tabbrowser-tabbox {
                  border: 4px solid ${accent} !important;
                }
              '';
            }
          ];
        }
        # --name sets the Wayland app_id, so Plasma groups these windows under this
        # launcher rather than the default profile's.
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          xdg.desktopEntries.firefox-personal = {
            name = "Firefox (personal)";
            genericName = "Web Browser";
            exec = "${firefox}/bin/firefox -P personal --name firefox-personal %U";
            icon = "${personal-icon}";
            categories = ["Network" "WebBrowser"];
            mimeType = ["text/html" "x-scheme-handler/http" "x-scheme-handler/https"];
            settings.StartupWMClass = "firefox-personal";
          };
        })
      ]))
    ];
  };
}
