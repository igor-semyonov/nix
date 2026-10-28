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
# FIFO queue, not balcon's own `-q`: two instances starting within ~1s of each other (a
# double-tapped hotkey, or one landing in the gap while a queued one takes over) both hang
# in exit, blocked on the wineserver pipe, until wine is killed.
#
# Each run holds a lock on its own ticket and waits on its predecessor's. The kernel drops
# a lock when its holder dies, so a killed run releases the next one instead of wedging
# the queue. wine must not inherit the lock fds: wineserver outlives the run and would
# keep the ticket locked.
queue="${XDG_RUNTIME_DIR:-/tmp}/tts-queue"
mkdir -p "$queue"
ticket="$queue/$$"
trap 'rm -f "$ticket"' EXIT
exec 8>"$queue/.tail"
flock 8
prev=$(cat "$queue/.tail-name" 2>/dev/null) || prev=""
exec 9>"$ticket"
flock 9
echo "$ticket" >"$queue/.tail-name"
exec 8>&-
# Opened read-only so a predecessor that already finished, and removed its ticket, is
# skipped rather than recreated.
if [[ -n $prev ]] && exec 7<"$prev"; then
    flock 7
    exec 7<&-
fi 2>/dev/null

echo "$text" | wine 'C:\balcon\balcon.exe' -i -n 'Microsoft Server Speech Text to Speech Voice (en-US, ZiraPro)' -s "$tts_speed" &>/dev/null 9>&-
