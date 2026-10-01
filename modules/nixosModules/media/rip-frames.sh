# Render a contact sheet of frames for each input video, so a title -> episode
# mapping can be checked against the picture before anything is encoded or
# named.
#
# This exists because none of the orderings a disc exposes -- MakeMKV's title
# index, the playlist number, the clip number -- is reliably episode order, and
# the failure is silent: a whole season lands mis-numbered and only shows up
# when someone watches it. Looking at six frames takes seconds and is the only
# check that cannot be fooled.
#
# Takes raw rips (title-*.mkv), finished library files, or directories of
# either.

count=6
cols=3
width=640
outdir=$PWD/rip-frames
declare -a inputs=()

while (($#)); do
    case $1 in
    -n | --count)
        count=$2
        shift 2
        ;;
    -c | --cols)
        cols=$2
        shift 2
        ;;
    -w | --width)
        width=$2
        shift 2
        ;;
    -o | --out)
        outdir=$2
        shift 2
        ;;
    -h | --help)
        cat <<'EOF'
usage: rip-frames [-n COUNT] [-c COLS] [-w WIDTH] [-o OUTDIR] FILE|DIR...

  -n  frames per sheet (default 6)
  -c  columns in the sheet (default 3)
  -w  frame width in pixels (default 640)
  -o  output directory (default ./rip-frames)

Frames are sampled evenly across the runtime, skipping the first and last
tenth so recaps and credits do not dominate. Sheet order is chronological,
left to right then top to bottom.
EOF
        exit 0
        ;;
    -*)
        echo "rip-frames: unknown option: $1" >&2
        exit 2
        ;;
    *)
        inputs+=("$1")
        shift
        ;;
    esac
done

((${#inputs[@]})) || {
    echo "rip-frames: no inputs; see --help" >&2
    exit 2
}

((count % cols == 0)) || {
    echo "rip-frames: --count ($count) must be a multiple of --cols ($cols)" >&2
    exit 2
}

# Directories expand to the videos directly inside them, non-recursively:
# a rip directory holds its titles flat, and recursing would pull in the
# scratch dirs of a rip still in progress.
declare -a files=()
for input in "${inputs[@]}"; do
    if [[ -d $input ]]; then
        while IFS= read -r f; do files+=("$f"); done \
            < <(find "$input" -maxdepth 1 -type f \
                \( -name '*.mkv' -o -name '*.mp4' -o -name '*.m2ts' \) | sort)
    elif [[ -f $input ]]; then
        files+=("$input")
    else
        echo "rip-frames: not found: $input" >&2
        exit 1
    fi
done

((${#files[@]})) || {
    echo "rip-frames: no video files among the inputs" >&2
    exit 1
}

mkdir -p "$outdir"
rows=$((count / cols))

for file in "${files[@]}"; do
    base=${file##*/}
    base=${base%.*}
    sheet=$outdir/$base.jpg

    duration=$(ffprobe -v error -show_entries format=duration \
        -of default=nw=1:nk=1 "$file")
    if [[ -z $duration || $duration == N/A ]]; then
        echo "rip-frames: no duration for $file, skipping" >&2
        continue
    fi

    work=$(mktemp -d)
    # shellcheck disable=SC2064 # expand work now, it is gone by trap time
    trap "rm -rf '$work'" EXIT

    stamps=""
    for ((k = 0; k < count; k++)); do
        # Sample across the middle 80%: the first tenth is recap and titles,
        # the last tenth is credits, and neither identifies an episode.
        ts=$(awk -v d="$duration" -v k="$k" -v n="$count" \
            'BEGIN { printf "%.3f", d * (0.1 + 0.8 * (k + 0.5) / n) }')
        # -ss before -i seeks by index instead of decoding from zero, which
        # matters on 9 GiB remuxes.
        ffmpeg -nostdin -v error -ss "$ts" -i "$file" \
            -frames:v 1 -vf "scale=$width:-2" \
            "$work/$(printf '%03d' "$k").jpg"
        stamps+="${stamps:+ }$(awk -v t="$ts" \
            'BEGIN { printf "%d:%02d:%02d", t/3600, (t%3600)/60, t%60 }')"
    done

    ffmpeg -nostdin -v error -y -i "$work/%03d.jpg" \
        -vf "tile=${cols}x${rows}" -frames:v 1 "$sheet"

    rm -rf "$work"
    trap - EXIT

    printf '%s\n  %s\n' "$sheet" "$stamps"
done
