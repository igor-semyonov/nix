# Drain the rip-request spool: for each request, decrypt and demux the disc with
# makemkvcon into the staging directory, then queue the resulting titles for AV1
# encoding. Runs as the media-rip user, the only account holding the MakeMKV key.

rip_queue=$MEDIA_STATE_DIR/rip-queue
encode_queue=$MEDIA_STATE_DIR/encode-queue
failed_dir=$rip_queue/failed

mkdir -p "$rip_queue" "$encode_queue" "$MEDIA_STATE_DIR/claims" "$failed_dir" "$MEDIA_RIP_DIR"

# makemkvcon only reads its key from $HOME; the unit points HOME at the state
# directory so this never lands in a real user's home.
install_key() {
    [[ -n $MAKEMKV_KEY_FILE && -r $MAKEMKV_KEY_FILE ]] || return 0
    local key
    key=$(tr -d '[:space:]' <"$MAKEMKV_KEY_FILE")
    mkdir -p "$HOME/.MakeMKV"
    printf 'app_Key = "%s"\n' "$key" >"$HOME/.MakeMKV/settings.conf"
    chmod 0600 "$HOME/.MakeMKV/settings.conf"
}

# Strip anything that would be awkward or unsafe in a path component.
sanitize() {
    tr -d '\000-\037/' <<<"$1" |
        sed -E 's/[:*?"<>|]/-/g; s/[[:space:]]+/ /g; s/^ +//; s/ +$//'
}

# THE_MATRIX -> The Matrix. All-caps labels are the norm; a mixed-case label is
# usually already correct, so leave that alone.
prettify() {
    local s=$1
    s=${s//[._]/ }
    [[ $s == "${s^^}" ]] && s=${s,,}
    sed -E 's/(^|[ ([-])([a-z])/\1\u\2/g' <<<"$s"
}

enqueue_encode() {
    local src=$1 dest=$2 tmp stamp
    tmp=$(mktemp "$encode_queue/.job-XXXXXX")
    stamp=$(date -u +%Y%m%dT%H%M%S.%N)
    jq -n --arg src "$src" --arg dest "$dest" '$ARGS.named' >"$tmp"
    mv "$tmp" "$encode_queue/$stamp.json"
    echo "media-rip: queued encode $src -> $dest"
}

# Called from an `if`, which disables errexit for everything below, so every
# fallible step has to check its own status.
process() {
    local request=$1
    local device kind name season first_episode titles min_length wait eject encode
    local scan stage stamp dest index i target scratch
    local -a selected produced fresh

    # shellcheck disable=SC2046 # @sh output is deliberately split into assignments
    eval $(jq -r '@sh "device=\(.device) kind=\(.kind) name=\(.name) season=\(.season // 1) first_episode=\(.first_episode // 1) titles=\(.titles // [] | join(",")) min_length=\(.min_length) wait=\(.wait) eject=\(.eject) encode=\(.encode)"' "$request")

    media-wait-for-disc "$device" "$wait" || return 1

    # rip-tv and interactive rip-movie resolve the selection with a human
    # present, so a request that carries both titles and a name needs nothing
    # from the disc but the data itself -- worth skipping, a Blu-ray scan is
    # about a minute.
    if [[ -n $titles && -n $name ]]; then
        mapfile -t selected < <(tr ',' '\n' <<<"$titles")
    else
        echo "media-rip: scanning $device"
        scan=$(media-disc-scan "$device" "$min_length") || {
            echo "media-rip: makemkvcon could not read $device" >&2
            return 1
        }

        if [[ -z $name ]]; then
            name=$(prettify "$(awk -F'\t' '$1 == "LABEL" { print $2 }' <<<"$scan")")
            [[ -n $name ]] || name="Unknown Disc $(date -u +%Y%m%d-%H%M%S)"
            echo "media-rip: no name given, using disc label -> '$name'"
        fi

        if [[ -n $titles ]]; then
            mapfile -t selected < <(tr ',' '\n' <<<"$titles")
        else
            mapfile -t selected < <(media-guess-titles --kind "$kind" <<<"$scan")
        fi
    fi

    name=$(sanitize "$name")

    if ((${#selected[@]} == 0)) || [[ -z ${selected[0]} ]]; then
        echo "media-rip: no usable title on $device" >&2
        return 1
    fi
    echo "media-rip: ripping title(s) ${selected[*]} as '$name'"

    stamp=$(date -u +%Y%m%dT%H%M%S)
    stage=$MEDIA_RIP_DIR/$stamp-$name
    mkdir -p "$stage" || return 1

    produced=()
    for index in "${selected[@]}"; do
        echo "media-rip: ripping title $index to $stage"

        # Each title gets a scratch directory so the single file makemkv writes
        # is unambiguous. Ripping straight into $stage and globbing would also
        # match the titles already renamed by previous iterations.
        scratch=$stage/.title-$index
        rm -rf "$scratch"
        mkdir -p "$scratch" || return 1

        makemkvcon --noscan --progress=-same --minlength="$min_length" \
            mkv "dev:$device" "$index" "$scratch" || {
            echo "media-rip: makemkvcon failed on title $index" >&2
            return 1
        }

        shopt -s nullglob
        fresh=("$scratch"/*.mkv)
        shopt -u nullglob
        if ((${#fresh[@]} == 0)); then
            echo "media-rip: makemkvcon produced nothing for title $index" >&2
            return 1
        fi

        target=$stage/$(printf 'title-%03d.mkv' "$index")
        mv "${fresh[0]}" "$target" || return 1
        rmdir "$scratch" 2>/dev/null || true
        produced+=("$target")
    done

    if [[ $eject == true ]]; then
        eject "$device" || echo "media-rip: eject failed, continuing" >&2
    fi

    if [[ $encode != true ]]; then
        echo "media-rip: encoding skipped, ${#produced[@]} title(s) left in $stage"
        return 0
    fi

    for i in "${!produced[@]}"; do
        if [[ $kind == tv ]]; then
            dest=$(media-library-path --kind tv --library "$MEDIA_LIBRARY_ROOT" \
                --name "$name" --season "$season" --episode "$((first_episode + i))")
        else
            dest=$(media-library-path --kind movie --library "$MEDIA_LIBRARY_ROOT" \
                --name "$name" --position "$i")
        fi
        enqueue_encode "${produced[$i]}" "$dest" || return 1
    done
}

install_key

shopt -s nullglob
requests=("$rip_queue"/*.json)
shopt -u nullglob
((${#requests[@]} > 0)) || exit 0
mapfile -t requests < <(printf '%s\n' "${requests[@]}" | sort)

# Checked once per run rather than per request: an expired key or build fails
# every disc identically, and the diagnosis belongs above the failures in the
# journal rather than repeated between them.
makemkv_usable=true
makemkv-status || makemkv_usable=false

for request in "${requests[@]}"; do
    # Requests are still moved aside rather than left queued: the path unit
    # retriggers while its glob matches, so holding them here would spin the
    # service. Recover with `mv failed/*.json ..` once MakeMKV works again.
    if [[ $makemkv_usable != true ]]; then
        echo "media-rip: MakeMKV unusable (see above), parking $request in $failed_dir" >&2
        mv "$request" "$failed_dir/"
        continue
    fi

    echo "media-rip: processing $request"
    if process "$request"; then
        rm -f "$request"
    else
        echo "media-rip: request failed, moved to $failed_dir" >&2
        mv "$request" "$failed_dir/"
    fi
done
