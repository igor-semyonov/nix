# Fetch subtitle sidecars for one or more video files (or directories of
# them) with subliminal.
#
# Replaces Bazarr, which cannot be used here: Bazarr has no library scanner of
# its own and takes its media list from the Sonarr/Radarr APIs, so pointing it
# at a plain directory does nothing. subliminal works directly on paths, which
# is what this pipeline already has -- the encode worker knows exactly which
# file it just produced.
#
# Called per-file by media-encode-worker, and usable by hand to backfill:
#
#   media-fetch-subtitles "/mnt/8tb/@media/tv/Some Show"
#   media-fetch-subtitles --age 7d /mnt/8tb/@media/tv

age=""
force=false
verbose=false
declare -a paths=()

while (($#)); do
    case $1 in
    -a | --age)
        age=$2
        shift 2
        ;;
    -f | --force)
        force=true
        shift
        ;;
    -v | --verbose)
        verbose=true
        shift
        ;;
    -h | --help)
        cat <<EOF
usage: media-fetch-subtitles [-a AGE] [-f] [-v] PATH...

  -a, --age AGE   only consider videos newer than AGE, e.g. 7d, 12h
  -f, --force     re-download even if a sidecar already exists
  -v, --verbose   pass through subliminal's progress output

Languages, providers and the minimum match score come from the module
configuration. Credentials are read from
\$MEDIA_SUBTITLE_CREDENTIALS_FILE and passed to subliminal through the
environment, never on the command line.

Languages: ${MEDIA_SUBTITLE_LANGUAGES:-(none configured)}
Providers: ${MEDIA_SUBTITLE_PROVIDERS:-(default set)}
EOF
        exit 0
        ;;
    -*)
        echo "media-fetch-subtitles: unknown option: $1" >&2
        exit 2
        ;;
    *)
        paths+=("$1")
        shift
        ;;
    esac
done

((${#paths[@]})) || {
    echo "media-fetch-subtitles: no paths given; see --help" >&2
    exit 2
}

if [[ -z ${MEDIA_SUBTITLE_LANGUAGES:-} ]]; then
    echo "media-fetch-subtitles: no languages configured, nothing to do" >&2
    exit 0
fi

# Credentials arrive as a KEY=VALUE file. It is parsed rather than sourced:
# sourcing would execute whatever is in it, and this runs as the service
# account. Only subliminal's own variables are accepted.
cred_file=${MEDIA_SUBTITLE_CREDENTIALS_FILE:-}
if [[ -n $cred_file ]]; then
    if [[ -r $cred_file ]]; then
        while IFS= read -r line; do
            [[ $line =~ ^SUBLIMINAL_[A-Z0-9_]+= ]] || continue
            export "${line?}"
        done <"$cred_file"
    else
        echo "media-fetch-subtitles: $cred_file is not readable; continuing with" \
            "anonymous providers only" >&2
    fi
fi

declare -a args=(download)
for lang in $MEDIA_SUBTITLE_LANGUAGES; do args+=(--language "$lang"); done
for prov in ${MEDIA_SUBTITLE_PROVIDERS:-}; do args+=(--provider "$prov"); done
[[ -n ${MEDIA_SUBTITLE_MIN_SCORE:-} ]] && args+=(--min-score "$MEDIA_SUBTITLE_MIN_SCORE")
[[ -n $age ]] && args+=(--age "$age")
[[ $force == true ]] && args+=(--force)
[[ $verbose == true ]] && args+=(--verbose)

# Blu-ray rips carry embedded PGS subtitles, which are bitmaps: they cannot be
# searched, restyled or scaled, so a text sidecar is still worth having.
# Without this subliminal treats the embedded track as good enough and skips
# the language entirely.
[[ ${MEDIA_SUBTITLE_FORCE_EMBEDDED:-} == 1 ]] && args+=(--force-embedded-subtitles)

exec subliminal "${args[@]}" -- "${paths[@]}"
