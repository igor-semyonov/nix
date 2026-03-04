# shellcheck disable=SC1078
tts_speed=''${1:-8}
# shellcheck disable=SC1009
text="''$(</dev/stdin)"

export WINEARCH=win32
export WINEPREFIX=$HOME/.wine32-tts

text=$(echo "$text" | iconv -f utf-8 -t ascii//translit)
# text=$(echo "$text" | tr -d "<>")
text=''${text//>/rangle}
text=''${text//</langle}

echo "$text" | wine 'C:\balcon\balcon.exe' -i -n 'Microsoft Server Speech Text to Speech Voice (en-US, ZiraPro)' -s "$tts_speed" &>/dev/null
