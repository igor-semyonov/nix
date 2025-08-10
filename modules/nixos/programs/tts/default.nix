{pkgs, ...}: let
  tts = pkgs.writeShellApplication {
    name = "tts-nix";
    runtimeInputs = [pkgs.wine-staging];
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
    name = "tts-nix-selection";
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
          tmp_dir=~/tmp-tts-dir
          mkdir $tmp_dir
          cd $tmp_dir
          wl-paste -p | ~/scripts/tts > ~/scripts/tts.sh.out 2>&1
          cd ~
          rm -rf $tmp_dir
      }

      # wl-paste && tts-wayland || tts-x
      tts-wayland
    '';
  };
in {
  environment.systemPackages = [
    tts
    tts-selection
  ];
}
