{pkgs, ...}: let
  tts = pkgs.writeShellApplication {
    name = "myWineApp";
    runtimeInputs = [pkgs.winePackages.staging];
    text = ''
      #!/usr/bin/env bash

      tts_speed=\$\{1:-8\}
      text="$(</dev/stdin)"
      echo $tts_speed

      export WINEARCH=win32
      export WINEPREFIX=$HOME/.wine32


      text=$(echo "$text" | iconv -f utf-8 -t ascii//translit)
      #text=$(echo "$text" | tr -d "<>")
      text=$(echo "$text" | sed -e 's/</langle/g')
      text=$(echo "$text" | sed -e 's/>/rangle/g')


      # echo "$text" | wine 'C:\balcon\balcon.exe' -i -n 'Microsoft Server Speech Text to Speech Voice (en-US, ZiraPro)' -s $tts_speed #&> /dev/null
    '';
  };
in {
  environment.systemPackages = [
    tts
    # tts-selection
  ];
}
