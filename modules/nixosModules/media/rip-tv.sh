# Queue a TV disc rip. Scans and confirms the episode selection here, as the
# invoking user, then hands a fully-resolved request to media-rip.service.

usage() {
    cat <<EOF
Usage: rip-tv SHOW --season N [--first-episode N] [options]

Scans the disc, pre-selects the titles that look like episodes, and asks you to
confirm before anything is ripped. The pre-selection is only a starting point:
a double-length season finale and a two-episode "play all" have the same
duration, so the disc cannot distinguish them and you get the final say.

The selection order is what maps titles onto episode numbers, so a disc that
lists its episodes out of order is fixed by reordering the selection.

  SHOW                    show name as Jellyfin should see it, e.g. "The Wire"
  -s, --season N          season number (default: 1)
  -e, --first-episode N   episode number of the disc's first title (default: 1)
  -d, --device DEV        optical device (default: $MEDIA_DEFAULT_DEVICE)
  -t, --titles LIST       skip the prompt and rip exactly these, e.g. 1,3,5,7
  -y, --yes               skip the prompt and accept the guess
      --tolerance PCT     width of the episode-length window used for the
                          initial guess (default: $MEDIA_EPISODE_TOLERANCE)
  -m, --min-length SEC    hide titles shorter than this (default: $MEDIA_TV_MIN_LENGTH)
  -P, --preset N          SVT-AV1 preset for this rip, overriding the module
                          default. Lower is slower and smaller.
  -w, --wait SEC          how long to wait for a disc (default: $MEDIA_WAIT)
  -E, --no-eject          leave the disc in the drive when the rip finishes
  -R, --no-encode         rip to staging only, skip AV1 encoding
  -h, --help              this message

Claims the drive the moment it starts, so the automatic movie rip that fires
on disc insertion stands down. Safe to run before or after inserting the disc.
EOF
}

device=$MEDIA_DEFAULT_DEVICE
name=""
season=1
first_episode=1
titles=""
tolerance=$MEDIA_EPISODE_TOLERANCE
min_length=$MEDIA_TV_MIN_LENGTH
wait_for=$MEDIA_WAIT
preset=""
eject=$MEDIA_EJECT
encode=true
assume_yes=false

while (($#)); do
    case $1 in
    -s | --season)
        season=$2
        shift 2
        ;;
    -e | --first-episode)
        first_episode=$2
        shift 2
        ;;
    -d | --device)
        device=$2
        shift 2
        ;;
    -t | --titles)
        titles=$2
        shift 2
        ;;
    -y | --yes)
        assume_yes=true
        shift
        ;;
    --tolerance)
        tolerance=$2
        shift 2
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
    -h | --help)
        usage
        exit 0
        ;;
    -*)
        echo "rip-tv: unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
    *)
        if [[ -n $name ]]; then
            echo "rip-tv: unexpected argument: $1" >&2
            exit 2
        fi
        name=$1
        shift
        ;;
    esac
done

# Unlike a film, a show name cannot be recovered from the disc label: labels
# like THE_WIRE_S2_D3 carry disc numbering that must not reach the library.
if [[ -z $name ]]; then
    echo "rip-tv: a show name is required" >&2
    usage >&2
    exit 2
fi

if [[ -n $titles ]] && ! [[ $titles =~ ^[0-9]+(,[0-9]+)*$ ]]; then
    echo "rip-tv: --titles must be a comma-separated list of indices" >&2
    exit 2
fi

queue=$MEDIA_STATE_DIR/rip-queue
claims=$MEDIA_STATE_DIR/claims

if [[ ! -w $queue ]]; then
    echo "rip-tv: cannot write $queue (are you in the media group?)" >&2
    exit 1
fi

# Claim before doing anything slow, so inserting the disc now cannot start an
# automatic movie rip while we are still scanning.
claim=$claims/$(basename "$device")
touch "$claim" 2>/dev/null || true
release_claim() { rm -f "$claim" 2>/dev/null || true; }

if [[ -z $titles ]]; then
    trap release_claim EXIT

    media-wait-for-disc "$device" "$wait_for" || exit 1

    echo "rip-tv: scanning $device (a Blu-ray takes about a minute)" >&2
    scan=$(media-disc-scan "$device" "$min_length")
    guess=$(media-guess-titles --kind tv --tolerance "$tolerance" <<<"$scan")
    label=$(awk -F'\t' '$1 == "LABEL" { print $2 }' <<<"$scan")

    if [[ $assume_yes == true ]]; then
        titles=$guess
        [[ -n $titles ]] || {
            echo "rip-tv: nothing on $device looks like an episode" >&2
            exit 1
        }
        echo "rip-tv: accepting guess: $titles" >&2
    else
        titles=$(media-pick-titles \
            --kind tv --guess "$guess" --label "$label" \
            --name "$name" --library "$MEDIA_LIBRARY_ROOT" \
            --season "$season" --first-episode "$first_episode" <<<"$scan") || exit 1
    fi

    trap - EXIT
fi

# The dot prefix keeps the half-written file out of the *.json path-unit glob.
tmp=$(mktemp "$queue/.request-XXXXXX")
trap 'rm -f "$tmp"; release_claim' EXIT

jq -n \
    --arg device "$device" \
    --arg name "$name" \
    --arg titles "$titles" \
    --argjson season "$season" \
    --argjson first_episode "$first_episode" \
    --argjson min_length "$min_length" \
    --arg preset "$preset" \
    --argjson wait "$wait_for" \
    --argjson eject "$eject" \
    --argjson encode "$encode" \
    '$ARGS.named
     | .kind = "tv"
     | .preset = (if $preset == "" then null else ($preset | tonumber) end)
     | .titles = ($titles | split(",") | map(tonumber))' >"$tmp"

chmod 0664 "$tmp"
mv "$tmp" "$queue/$(date -u +%Y%m%dT%H%M%S.%N).json"
trap - EXIT

# Safe to release now: the queued request itself is what holds off the
# automatic rip from here on, and leaving the claim behind would disable it
# for every future disc.
release_claim

printf 'rip-tv: queued %s S%02d from episode %d, titles %s\n' \
    "$name" "$season" "$first_episode" "$titles"
