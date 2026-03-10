{...}: {
  flake.homeModules.anyrun = {
    pkgs,
    osConfig,
    ...
  }: {
    home.packages = with pkgs; [
      anyrun
      wl-clipboard
    ];
    programs.anyrun = {
      enable = true;
      config = {
        x.fraction = 0.45;
        y.fraction = 0.5;
        width.fraction = 0.8;
        height.fraction = 0.7;

        closeOnClick = true;
        showResultsImmediately = false;
        plugins = [
          "${pkgs.anyrun}/lib/libnix_run.so"
          "${pkgs.anyrun}/lib/libapplications.so"
          "${pkgs.anyrun}/lib/libsymbols.so"
          "${pkgs.anyrun}/lib/librink.so"
          "${pkgs.anyrun}/lib/libdictionary.so"
          "${pkgs.anyrun}/lib/libwebsearch.so"
        ];
        maxEntries = 7;
        margin = 1;
      };
      extraCss =
        /*
        css
        */
        ''
          @define-color accent #5599d2;
          @define-color bg-color #161616;
          @define-color bg-color-match #206020;
          @define-color fg-color #eeeeee;
          @define-color desc-color #cccccc;

          window {
            background: transparent;
          }

          box.main {
            padding: 5px;
            margin: 10px;
            border-radius: 10px;
            border: 6px solid @accent;
            background-color: @bg-color;
            box-shadow: 0 0 5px black;
          }

          text {
            min-height: 30px;
            padding: 5px;
            border-radius: 5px;
            color: @fg-color;
            font-size: 42px;
          }

          .matches {
            background-color: rgba(0, 0, 0, 0);
            border-radius: 10px;
          }

          box.plugin:first-child {
            margin-top: 8px;
          }

          box.plugin.info {
            font-size: 42px;
            # min-width: 440px;
            margin-right: 21px;
          }

          list.plugin {
            background-color: rgba(0, 0, 0, 0);
          }

          .match GtkImage {
            -gtk-icon-size: 64px;
            font-size: 72px;
            margin-right: 15px;
          }
          .info GtkImage {
            -gtk-icon-size: 72px;
            font-size: 72px;
            margin-right: 15px;
          }

          label.match {
            font-size: 64px;
            color: @fg-color;
          }

          label.match.description {
            font-size: 42px;
            color: @desc-color;
          }

          label.plugin.info {
            # font-size: 64px;
            color: @fg-color;
          }

          .match {
            background: transparent;
          }

          .match:selected {
            border: 4px solid @accent;
            background: @bg-color-match;
            animation: fade 0.25s ease-out;
          }

          @keyframes fade {
            0% {
              # opacity: 0;
              transform: scale(1.0);
            }
            50% {
              # opacity: 0.5;
              transform: scale(1.1);
            }
            100% {
              # opacity: 1;
              transform: scale(1.0);
            }
          }
        '';
      extraConfigFiles = {
        "websearch.ron".text = ''
          Config(
            // Set a trigger so web searches don't clutter local app searches
            prefix: "?",

            // Define your search engines. The first one listed is the default.
            engines: [
              DuckDuckGo,
              Google,
              Custom(
                name: "rs (Rust Docs)",
                url: "doc.rust-lang.org/stable/std/index.html?search={}",
              ),
              Custom(
                name: "Nix Packages",
                url: "search.nixos.org/packages?channel=unstable&query={}",
              ),
              Custom(
                name: "Royal Road",
                url: "www.royalroad.com/fictions/search?title={}",
              )
            ]
          )
        '';
        "nix-run.ron".text = ''
          Config(
            prefix: ":nr",
            allow_unfree: false,
            channel: "nixpkgs-unstable",
            max_entries: 5,
          )
        '';
        "dictionary.ron".text = ''
          Config(
            prefix: ":def",
            max_entries: 5,
          )
        '';
        "symbols.ron".text = ''
          Config(
            prefix: ":sym",
            // Custom user defined symbols to be included along the unicode symbols
            symbols: {
              // "name": "text to be copied"
              "shrug": "¯\\_(ツ)_/¯",
            },
            max_entries: 5,
          )
        '';
      };
    };
  };
}
