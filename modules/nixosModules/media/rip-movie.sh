# Queue a movie rip. Resolves the title selection here, as the invoking user,
# then hands a request to media-rip.service.

usage() {
    cat <<EOF
Usage: rip-movie [NAME] [options]

Rips the longest title on the disc -- on a feature disc that is the film, and
everything else is trailers, idents and playlist decoys. Unlike a TV disc this
guess is reliable, so it is taken without prompting unless you ask.

  NAME                    library name, ideally "Title (Year)". Omitted, it is
                          derived from the disc label.
  -d, --device DEV        optical device (default: $MEDIA_DEFAULT_DEVICE)
  -t, --titles LIST       rip exactly these title indices, e.g. 0,4. The first
                          is the feature, the rest become extras.
  -p, --part N            this disc holds part N of a film split across discs.
                          Jellyfin stacks the parts into one playable item.
                          Only for a genuinely split film -- a two-disc set
                          whose second disc is bonus material is not this.
  -i, --interactive       show the titles and confirm before ripping, e.g. to
                          choose between a theatrical and an extended cut
  -m, --min-length SEC    ignore titles shorter than this (default: $MEDIA_MIN_LENGTH)
  -P, --preset N          SVT-AV1 preset for this rip, overriding the module
                          default. Lower is slower and smaller.
  -w, --wait SEC          how long to wait for a disc (default: $MEDIA_WAIT)
  -E, --no-eject          leave the disc in the drive when the rip finishes
  -R, --no-encode         rip to staging only, skip AV1 encoding
      --if-unclaimed      do nothing if this drive is claimed or already has a
                          queued request. Used by the disc-insertion unit.
  -h, --help              this message

Extra titles beyond the first land in the movie's extras/ subdirectory, where
Jellyfin reads them as bonus content rather than as alternate versions.
EOF
}

device=$MEDIA_DEFAULT_DEVICE
name=""
titles=""
part=0
min_length=$MEDIA_MIN_LENGTH
wait_for=$MEDIA_WAIT
preset=""
eject=$MEDIA_EJECT
encode=true
interactive=false
if_unclaimed=false

while (($#)); do
    case $1 in
    -d | --device)
        device=$2
        shift 2
        ;;
    -t | --titles)
        titles=$2
        shift 2
        ;;
    -p | --part)
        part=$2
        shift 2
        ;;
    -i | --interactive)
        interactive=true
        shift
        ;;
    -m | --min-length)
        min_length=$2
        shift 2
        ;;
    -P | --preset)
        preset=$2
        shift 2
        ;;
    -w | --wait)
        wait_for=$2
        shift 2
        ;;
    -E | --no-eject)
        eject=false
        shift
        ;;
    -R | --no-encode)
        encode=false
        shift
        ;;
    --if-unclaimed)
        if_unclaimed=true
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    -*)
        echo "rip-movie: unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
    *)
        if [[ -n $name ]]; then
            echo "rip-movie: unexpected argument: $1" >&2
            exit 2
        fi
        name=$1
        shift
        ;;
    esac
done

if [[ -n $titles ]] && ! [[ $titles =~ ^[0-9]+(,[0-9]+)*$ ]]; then
    echo "rip-movie: --titles must be a comma-separated list of indices" >&2
    exit 2
fi

queue=$MEDIA_STATE_DIR/rip-queue
claims=$MEDIA_STATE_DIR/claims
claim=$claims/$(basename "$device")

# The automatic rip must never fight a deliberate one. Two things can hold it
# off: a claim taken by rip-tv or an interactive rip-movie, or a request for
# this drive already sitting in the queue.
if [[ $if_unclaimed == true ]]; then
    if [[ -e $claim ]]; then
        echo "rip-movie: $device is claimed by a manual rip, standing down"
        exit 0
    fi
    shopt -s nullglob
    for pending in "$queue"/*.json; do
        if [[ $(jq -r '.device // ""' "$pending" 2>/dev/null) == "$device" ]]; then
            echo "rip-movie: $device already has a queued request, standing down"
            exit 0
        fi
    done
    shopt -u nullglob
fi

if [[ ! -w $queue ]]; then
    echo "rip-movie: cannot write $queue (are you in the media group?)" >&2
    exit 1
fi

release_claim() { rm -f "$claim" 2>/dev/null || true; }

if [[ -z $titles && $interactive == true ]]; then
    touch "$claim" 2>/dev/null || true
    trap release_claim EXIT

    media-wait-for-disc "$device" "$wait_for" || exit 1

    echo "rip-movie: scanning $device (a Blu-ray takes about a minute)" >&2
    scan=$(media-disc-scan "$device" "$min_length")
    guess=$(media-guess-titles --kind movie <<<"$scan")
    label=$(awk -F'\t' '$1 == "LABEL" { print $2 }' <<<"$scan")

    # The disc label stands in for the name when none was given, matching what
    # the worker would derive, so the preview shows the real destination.
    titles=$(media-pick-titles --kind movie --guess "$guess" --label "$label" \
        --name "${name:-$label}" --library "$MEDIA_LIBRARY_ROOT" <<<"$scan") || exit 1

    trap - EXIT
    release_claim
fi

# The dot prefix keeps the half-written file out of the *.json path-unit glob.
tmp=$(mktemp "$queue/.request-XXXXXX")
trap 'rm -f "$tmp"' EXIT

jq -n \
    --arg device "$device" \
    --arg name "$name" \
    --arg titles "$titles" \
    --argjson part "$part" \
    --argjson min_length "$min_length" \
    --arg preset "$preset" \
    --argjson wait "$wait_for" \
    --argjson eject "$eject" \
    --argjson encode "$encode" \
    '$ARGS.named
     | .kind = "movie"
     | .preset = (if $preset == "" then null else ($preset | tonumber) end)
     | .titles = (if $titles == "" then null else ($titles | split(",") | map(tonumber)) end)' >"$tmp"

chmod 0664 "$tmp"
mv "$tmp" "$queue/$(date -u +%Y%m%dT%H%M%S.%N).json"
trap - EXIT

echo "rip-movie: queued ${name:-<disc label>} from $device"
