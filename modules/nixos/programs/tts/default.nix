{pkgs, ...}: let
  tts = pkgs.writeShellApplication {
    name = "tts";
    runtimeInputs = [pkgs.stable.wine-staging];
    text = ''
      tts_speed=''${1:-8}
      text="''$(</dev/stdin)"

      export WINEARCH=win32
      export WINEPREFIX=$HOME/.wine32

      text=$(echo "$text" | iconv -f utf-8 -t ascii//translit)
      # text=$(echo "$text" | tr -d "<>")
      text=''${text//>/rangle}
      text=''${text//</langle}


      echo "$text" | wine 'C:\balcon\balcon.exe' -i -n 'Microsoft Server Speech Text to Speech Voice (en-US, ZiraPro)' -s "$tts_speed" &> /dev/null
    '';
  };
  tts-selection = pkgs.writeShellApplication {
    name = "tts-selection";
    runtimeInputs = [tts pkgs.wl-clipboard];
    text = ''
      function tts-x() {
          echo x11
          tmp_dir=~/tmp-tts-dir
          mkdir $tmp_dir
          cd $tmp_dir
          xclip -o | ~/scripts/tts > ~/scripts/tts.sh.out 2>&1
          cd ~
          rm -rf $tmp_dir
      }

      function tts-wayland() {
          echo wayland
          wl-paste -p | tts
      }

      # wl-paste && tts-wayland || tts-x
      tts-wayland
    '';
  };
  tts-screen = pkgs.writeShellApplication {
    name = "tts-screen";
    runtimeInputs = [tts pkgs.kdePackages.spectacle pkgs.tesseract];
    text = ''
      if [ -f /tmp/tts.tif ]; then
        rm /tmp/tts.tif
      fi
      spectacle -nbfo /tmp/tts.tif
      if [ -f /tmp/tts.tif ]; then
        tesseract -l eng /tmp/tts.tif /tmp/tts
        # shellcheck disable=SC2002
        cat /tmp/tts.txt | tts
      fi
    '';
  };
  tts-region = pkgs.writeShellApplication {
    name = "tts-region";
    runtimeInputs = [tts pkgs.kdePackages.spectacle pkgs.tesseract];
    text = ''
      if [ -f /tmp/tts.tif ]; then
        rm /tmp/tts.tif
      fi
      spectacle -nbro /tmp/tts.tif
      if [ -f /tmp/tts.tif ]; then
        tesseract -l eng /tmp/tts.tif /tmp/tts
        # shellcheck disable=SC2002
        cat /tmp/tts.txt | tts
      fi
    '';
  };
in {
  environment.systemPackages = [
    tts
    tts-selection
    tts-screen
    tts-region
  ];
}
