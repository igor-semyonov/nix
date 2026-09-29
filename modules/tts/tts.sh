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

# Deliberately NO `-fr`: the voice stays at its native 16kHz. Forcing 44.1k to match the
# graph looked like a free win -- pipewire would resample nothing -- but it put speech on a
# rate inside `igix.sound.allowedRates`, which made every utterance a candidate for a DAC
# retune. The resulting suspend/resume cycle closed the device for ~0.4s mid-sentence and
# ate the opening words. Measured: with the retune watcher running, a device poll during
# playback showed CLOSED; with it stopped, 100/100 samples stayed open.
#
# 16kHz is not a rate any DAC here can clock, so it can never appear in allowedRates, and
# speech is therefore invisible to rate selection. That is the property the whole design
# leans on. Resampling 16k on the realtime path is the cost, and it is inaudible.
#
# -q: wait for any already-running copy to finish instead of talking over it, so selecting
# several passages in a row queues them. Nothing previously enforced this.
echo "$text" | wine 'C:\balcon\balcon.exe' -i -n 'Microsoft Server Speech Text to Speech Voice (en-US, ZiraPro)' -s "$tts_speed" -q &>/dev/null
