{
  pkgs,
  lib,
  outputs,
  ...
}: {
  programs.firefox = {
    enable = true;
    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;
        settings = {
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
            "Google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
          };
        };
        extensions = {
          packages = with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            bitwarden
            darkreader
            vimium
            tree-style-tab
            tabliss
          ];
          settings = {
            "treestyletab@piro.sakura.ne.jp" = {
              force = true;
              permissions = [ "activeTab" "contextualIdentities" "cookies" "menus" "menus.overrideContext" "search" "sessions" "storage" "tabGroups" "theme" "notifications" "tabs"];
            };
          };
        };
      };
    };
  };
}
