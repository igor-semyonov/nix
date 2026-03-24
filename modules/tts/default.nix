{self, ...}: {
  flake = {
    nixosModules.programs-tts = {pkgs, ...}: let
      tts = pkgs.writeShellApplication {
        name = "tts";
        runtimeInputs = with pkgs; [
          stable.wine-staging
          python314
          # glibcLocales
        ];
        text = builtins.readFile ./tts.sh;
        # text = ''
        #   # shellcheck disable=all
        #   export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
        #   export LANG="en_US.UTF-8"
        #   export LC_ALL="en_US.UTF-8"
        #   ${builtins.readFile ./tts.sh}
        # '';
      };
      tts-selection = pkgs.writeShellApplication {
        name = "tts-selection";
        runtimeInputs = [tts pkgs.wl-clipboard];
        text = builtins.readFile ./tts-selection.sh;
      };
      tts-screen = pkgs.writeShellApplication {
        name = "tts-screen";
        runtimeInputs = [tts pkgs.kdePackages.spectacle pkgs.tesseract];
        text = builtins.readFile ./tts-screen.sh;
      };
      tts-region = pkgs.writeShellApplication {
        name = "tts-region";
        runtimeInputs = [tts pkgs.kdePackages.spectacle pkgs.tesseract];
        text = builtins.readFile ./tts-region.sh;
      };
    in {
      environment.systemPackages = [
        tts
        tts-selection
        tts-screen
        tts-region
      ];
    };
    homeModules.tts = {
      pkgs,
      lib,
      config,
      ...
    }: {
      home.packages = [pkgs.unzip];
      home.activation.downloadAndUnzip = lib.hm.dag.entryAfter ["writeBoundary"] ''
        TARGET_PATH="${config.home.homeDirectory}"
        WINE_PREFIX=$TARGET_PATH/.wine32-tts

        # Check if the target directory already exists
        if [[ ! -d "$WINE_PREFIX" ]]; then
          $DRY_RUN_CMD echo "Directory $WINE_PREFIX not found. Downloading and extracting..."

          $DRY_RUN_CMD ${pkgs.unzip}/bin/unzip -q "${self}/assets/wine-tts.zip" -d "$TARGET_PATH"
        else
          $DRY_RUN_CMD echo "Directory $WINE_PREFIX already exists. Skipping ZIP extraction."
        fi
      '';
    };
  };
}
