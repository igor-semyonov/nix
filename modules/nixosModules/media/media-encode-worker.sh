# Drain the encode queue: re-encode each staged MakeMKV rip to AV1 with SVT-AV1
# and move the result into the Jellyfin library. Jobs run one at a time; SVT-AV1
# at these presets already saturates the machine.

encode_queue=$MEDIA_STATE_DIR/encode-queue
failed_dir=$encode_queue/failed

mkdir -p "$encode_queue" "$failed_dir" "$MEDIA_TRANSCODE_DIR"

# Keeps Jellyfin from indexing half-written encodes even when the transcode
# directory sits inside a library root. Created only when absent and never
# fatal: truncating it would abort the whole run under errexit if the file ever
# ends up owned by someone else.
[[ -e $MEDIA_TRANSCODE_DIR/.ignore ]] || : >"$MEDIA_TRANSCODE_DIR/.ignore" 2>/dev/null || true

# ffprobe reports these as rationals ("35400/50000"); shared by the HDR queries.
# shellcheck disable=SC2016 # jq program text, not shell expansion
jq_helpers='
  def num: if type == "string" then (split("/") | (.[0] | tonumber) / (.[1] | tonumber)) else . end;
  def r4: (. * 10000 | round) / 10000;
  def sd($t): (.frames[0].side_data_list // []) | map(select(.side_data_type == $t)) | .[0] // empty;
'

# SVT-AV1 does not inherit HDR10 static metadata from the demuxer, so mastering
# display and content light level have to be handed over explicitly. The
# transfer function itself rides along in ffmpeg's -color_trc; SVT-AV1 dropped
# the old --enable-hdr switch.
hdr_params() {
    local probe=$1 mastering light out
    mastering=$(jq -r "$jq_helpers"'
    sd("Mastering display metadata")
    | "G(\(.green_x|num|r4),\(.green_y|num|r4))B(\(.blue_x|num|r4),\(.blue_y|num|r4))R(\(.red_x|num|r4),\(.red_y|num|r4))WP(\(.white_point_x|num|r4),\(.white_point_y|num|r4))L(\(.max_luminance|num|r4),\(.min_luminance|num|r4))"
  ' <<<"$probe")
    light=$(jq -r "$jq_helpers"'sd("Content light level metadata") | "\(.max_content),\(.max_average)"' <<<"$probe")

    out=""
    [[ -n $mastering ]] && out+=":mastering-display=$mastering"
    [[ -n $light ]] && out+=":content-light=$light"
    printf '%s' "$out"
}

# Called from an `if`, which disables errexit for the whole body, so each
# fallible step checks its own status.
# MakeMKV splits a DTS-HD MA stream into two Matroska tracks: the lossless
# track and the backward-compatible DTS core it already contains. The core is a
# bit-exact subset -- decoding the MA track with the decoder's core_only option
# produces PCM identical to decoding the standalone core track -- so a player
# that cannot handle MA still gets the same audio from the MA track alone.
# Carrying it separately costs ~0.46 GiB per episode and gains nothing.
#
# Only a plain-"DTS" track shadowed by a "DTS-HD *" track in the *same
# language* is dropped, so a genuine second language or a lone DTS track is
# never touched.
redundant_dts_cores() {
    ffprobe -v error -print_format json -select_streams a \
        -show_entries stream=index,profile:stream_tags=language "$1" |
        jq -r '
      [.streams[]] as $a
      | $a[]
      | select((.profile // "") == "DTS")
      | . as $core
      | select(any($a[];
          (.profile // "") | startswith("DTS-HD")
        ) and any($a[];
          ((.profile // "") | startswith("DTS-HD"))
          and ((.tags.language // "") == ($core.tags.language // ""))
        ))
      | .index
    '
}

encode() {
    local src=$1 dest=$2 preset=${3:-$MEDIA_PRESET}
    local probe primaries transfer matrix range svt_params tmp label title pix_fmt src_pix
    local -a color_args=() audio_args=() map_args=()

    probe=$(ffprobe -v error -print_format json -select_streams v:0 \
        -show_streams -show_frames -read_intervals '%+#1' "$src") || return 1

    primaries=$(jq -r '.streams[0].color_primaries // ""' <<<"$probe")
    transfer=$(jq -r '.streams[0].color_transfer // ""' <<<"$probe")
    matrix=$(jq -r '.streams[0].color_space // ""' <<<"$probe")
    range=$(jq -r '.streams[0].color_range // ""' <<<"$probe")

    # "auto" matches the source depth. Encoding an 8-bit SDR disc at 10 bits
    # gains nothing measurable -- there is no precision to preserve -- and
    # browsers refuse 10-bit AV1 over MSE, which forces a wasteful re-encode on
    # the way to the client. HDR is always 10-bit regardless of what the
    # container claims.
    pix_fmt=$MEDIA_PIX_FMT
    if [[ $pix_fmt == auto ]]; then
        src_pix=$(jq -r '.streams[0].pix_fmt // ""' <<<"$probe")
        case $src_pix in
        *10le | *10be | *12le | *12be | *p010* | *p016*) pix_fmt=yuv420p10le ;;
        *) pix_fmt=yuv420p ;;
        esac
        case $transfer in
        smpte2084 | arib-std-b67) pix_fmt=yuv420p10le ;;
        esac
        echo "media-encode: source is $src_pix, encoding $pix_fmt"
    fi

    svt_params="tune=$MEDIA_SVT_TUNE:film-grain=$MEDIA_FILM_GRAIN:film-grain-denoise=$MEDIA_FILM_GRAIN_DENOISE:enable-overlays=1:scd=1"
    [[ -n $MEDIA_SVT_EXTRA ]] && svt_params+=":$MEDIA_SVT_EXTRA"

    if [[ $transfer == smpte2084 || $transfer == arib-std-b67 ]]; then
        echo "media-encode: HDR source ($transfer), forwarding static metadata"
        svt_params+=$(hdr_params "$probe")
        color_args=(-color_primaries "$primaries" -color_trc "$transfer" -colorspace "$matrix")
        [[ -n $range ]] && color_args+=(-color_range "$range")
    fi

    if [[ $MEDIA_AUDIO == opus ]]; then
        audio_args=(-c:a libopus -b:a "$MEDIA_OPUS_BITRATE")
    else
        audio_args=(-c:a copy)
    fi

    # Default to every audio track; narrow it only if a redundant core is
    # actually found, so a probe failure or an unexpected layout keeps the
    # previous behaviour rather than silently dropping audio.
    map_args=(-map '0:a?')
    if [[ $MEDIA_DROP_DTS_CORE == true ]]; then
        local -a drop=()
        mapfile -t drop < <(redundant_dts_cores "$src")
        if ((${#drop[@]} > 0)); then
            local -a keep=()
            local idx
            while read -r idx; do
                [[ -n $idx ]] || continue
                printf '%s\n' "${drop[@]}" | grep -qxF "$idx" || keep+=(-map "0:$idx")
            done < <(ffprobe -v error -select_streams a \
                -show_entries stream=index -of csv=p=0 "$src")
            if ((${#keep[@]} > 0)); then
                map_args=("${keep[@]}")
                echo "media-encode: dropping redundant DTS core track(s): ${drop[*]}"
            fi
        fi
    fi

    label=$(basename "$dest")
    tmp=$MEDIA_TRANSCODE_DIR/$$.$label
    # MakeMKV stamps the container title with the disc label, and -c copy
    # carries it through. Left alone it leaks into every player, and Jellyfin
    # shows it verbatim if "prefer embedded titles" is ever enabled.
    title=${label%.mkv}
    echo "media-encode: $src -> $dest (preset $preset, crf $MEDIA_CRF)"

    # Explicit stream selection rather than `-map 0`: MakeMKV emits timecode and
    # other data streams that Matroska cannot remux. `t` keeps cover attachments.
    ffmpeg -nostdin -hide_banner -y -nostats -loglevel warning \
        -i "$src" \
        -map 0:v "${map_args[@]}" -map '0:s?' -map '0:t?' \
        -c:s copy \
        -c:v libsvtav1 \
        -preset "$preset" \
        -crf "$MEDIA_CRF" \
        -pix_fmt "$pix_fmt" \
        -g "$MEDIA_KEYINT" \
        -svtav1-params "$svt_params" \
        "${color_args[@]}" \
        "${audio_args[@]}" \
        -metadata title="$title" \
        -max_muxing_queue_size 4096 \
        -progress pipe:1 \
        "$tmp" |
        awk -F= -v name="$label" '
      $1 == "out_time" { t = $2 }
      $1 == "speed"    { s = $2 }
      $1 == "progress" { if (++n % 300 == 0 || $2 == "end") printf("media-encode: %s at %s (%s)\n", name, t, s); fflush() }
    ' || {
        rm -f "$tmp"
        return 1
    }

    # Never clobber: two discs of one title, or a re-rip under a name already in
    # the library, would otherwise silently replace hours of finished work.
    if [[ -e $dest ]]; then
        echo "media-encode: $dest already exists, refusing to overwrite" >&2
        echo "media-encode:   for a film spanning discs use rip-movie --part N," >&2
        echo "media-encode:   otherwise delete the existing file to replace it." >&2
        echo "media-encode:   the new encode is kept at $tmp" >&2
        return 1
    fi

    mkdir -p "$(dirname "$dest")" || return 1
    # Same filesystem as the library by construction, so this is an atomic rename
    # and Jellyfin never sees a partial file.
    mv -f "$tmp" "$dest" || return 1
    chmod 0664 "$dest"

    if [[ $MEDIA_KEEP_RIPS != true ]]; then
        rm -f "$src"
        rmdir --ignore-fail-on-non-empty "$(dirname "$src")" || true
    fi
}

notify_jellyfin() {
    [[ -n $MEDIA_JELLYFIN_URL && -n $MEDIA_JELLYFIN_API_KEY_FILE && -r $MEDIA_JELLYFIN_API_KEY_FILE ]] || return 0
    curl -fsS -X POST \
        -H "Authorization: MediaBrowser Token=$(tr -d '[:space:]' <"$MEDIA_JELLYFIN_API_KEY_FILE")" \
        -H 'Content-Length: 0' \
        "$MEDIA_JELLYFIN_URL/Library/Refresh" ||
        echo "media-encode: library refresh request failed" >&2
}

shopt -s nullglob
queue=("$encode_queue"/*.json)
shopt -u nullglob
((${#queue[@]} > 0)) || exit 0
mapfile -t queue < <(printf '%s\n' "${queue[@]}" | sort)

encoded=0
for job in "${queue[@]}"; do
    src=$(jq -r '.src' "$job")
    dest=$(jq -r '.dest' "$job")
    if [[ ! -f $src ]]; then
        echo "media-encode: source $src is gone, dropping $job" >&2
        mv "$job" "$failed_dir/"
        continue
    fi
    jobpreset=$(jq -r '.preset // empty' "$job")
    if encode "$src" "$dest" "${jobpreset:-$MEDIA_PRESET}"; then
        rm -f "$job"
        encoded=$((encoded + 1))
        # Before Jellyfin is told to rescan, so the episode is indexed with its
        # sidecars instead of needing a second pass. A provider being down or
        # out of quota must not fail an encode that already succeeded.
        if [[ -n ${MEDIA_SUBTITLE_LANGUAGES:-} ]]; then
            media-fetch-subtitles "$dest" ||
                echo "media-encode: subtitle fetch failed for $dest, continuing" >&2
        fi
    else
        echo "media-encode: job failed, moved to $failed_dir" >&2
        mv "$job" "$failed_dir/"
    fi
done

if ((encoded > 0)); then
    notify_jellyfin
fi
