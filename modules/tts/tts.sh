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

# -fr 44: emit 44.1kHz instead of the voice's native 16kHz, matching the graph rate so
# pipewire resamples nothing. balcon converts internally via its bundled libsamplerate.dll.
# The voice is still a 16kHz source so this buys no detail -- it moves the conversion off
# the realtime path, and keeps the ratio fixed regardless of what rate the DAC is clocked
# at for music.
#
# No silence padding: `igix.sound.suspendTimeout = 0` keeps the DAC open, so there is no
# wake gap for the opening syllables to fall into and nothing to pad against.
#
# -q: wait for any already-running copy to finish instead of talking over it. Selecting
# several passages in a row queues them rather than playing them concurrently. Nothing
# previously enforced this -- overlapping invocations just happened not to collide.
echo "$text" | wine 'C:\balcon\balcon.exe' -i -n 'Microsoft Server Speech Text to Speech Voice (en-US, ZiraPro)' -s "$tts_speed" -fr 44 -q &>/dev/null
