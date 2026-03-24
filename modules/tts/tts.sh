# shellcheck disable=SC1078
tts_speed=''${1:-8}
# shellcheck disable=SC1009
text="''$(</dev/stdin)"

export WINEARCH=win32
export WINEPREFIX=$HOME/.wine32-tts

text=$(echo "$text" | python3 -c "
    import sys, unicodedata
    text = sys.stdin.read()
    # Normalize to decompose characters and diacritics, then drop non-ASCII
    transliterated = unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode('ascii')
    sys.stdout.write(transliterated)
    ")
# text=$(echo "$text" | iconv -f utf-8 -t ascii//translit//IGNORE)
# text=$(echo "$text" | tr -d "<>")
text=''${text//>/rangle}
text=''${text//</langle}
text=" ${text}" # Preppending a space fixes some pronunciation

echo "$text" | wine 'C:\balcon\balcon.exe' -i -n 'Microsoft Server Speech Text to Speech Voice (en-US, ZiraPro)' -s "$tts_speed" &>/dev/null
