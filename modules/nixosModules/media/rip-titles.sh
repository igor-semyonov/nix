# Show what is on the disc without ripping anything. Scanning needs no MakeMKV
# key, so this runs as the invoking user.

usage() {
    cat <<EOF
Usage: rip-titles [options]

  -d, --device DEV        optical device (default: $MEDIA_DEFAULT_DEVICE)
  -m, --min-length SEC    hide titles shorter than this (default: $MEDIA_TV_MIN_LENGTH,
                          the lower of the two floors, so nothing is hidden)
      --tolerance PCT     episode window for the tv guess (default: $MEDIA_EPISODE_TOLERANCE)
  -h, --help              this message

rip-tv shows the same table and lets you edit the selection, so this is only
for looking at a disc before deciding what to do with it.
EOF
}

device=$MEDIA_DEFAULT_DEVICE
min_length=$MEDIA_TV_MIN_LENGTH
tolerance=$MEDIA_EPISODE_TOLERANCE

while (($#)); do
    case $1 in
    -d | --device)
        device=$2
        shift 2
        ;;
    -m | --min-length)
        min_length=$2
        shift 2
        ;;
    --tolerance)
        tolerance=$2
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "rip-titles: unknown argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
done

if [[ ! -b $device ]]; then
    echo "rip-titles: $device is not a block device" >&2
    exit 1
fi

echo "rip-titles: scanning $device (a Blu-ray takes about a minute)" >&2
scan=$(media-disc-scan "$device" "$min_length")

label=$(awk -F'\t' '$1 == "LABEL" { print $2 }' <<<"$scan")
movie_guess=$(media-guess-titles --kind movie <<<"$scan")
tv_guess=$(media-guess-titles --kind tv --tolerance "$tolerance" <<<"$scan")

printf 'Disc: %s\n\n' "$label"
printf '  %5s %10s %8s %10s\n' idx duration chapters size
awk -F'\t' '$1 == "TITLE" { printf "  %5d %10s %8s %10s\n", $2, $4, $5, $6 }' <<<"$scan"

printf '\nrip-movie would take: %s\n' "${movie_guess:-nothing}"
printf 'rip-tv would suggest: %s\n' "${tv_guess:-nothing}"
