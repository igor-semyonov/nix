# Print the library destination for one ripped title. Single definition of the
# naming scheme and of the sanitising that goes with it, so the path rip-tv
# shows you for confirmation is the path the worker actually writes.

kind=movie
library=${MEDIA_LIBRARY_ROOT:-}
name=""
season=1
episode=1
position=0

while (($#)); do
    case $1 in
    -k | --kind)
        kind=$2
        shift 2
        ;;
    -l | --library)
        library=$2
        shift 2
        ;;
    -n | --name)
        name=$2
        shift 2
        ;;
    -s | --season)
        season=$2
        shift 2
        ;;
    -e | --episode)
        episode=$2
        shift 2
        ;;
    -p | --position)
        position=$2
        shift 2
        ;;
    *)
        echo "media-library-path: unknown argument: $1" >&2
        exit 2
        ;;
    esac
done

# Strip anything that would be awkward or unsafe in a path component. The
# substitutions matter to Jellyfin too: a colon cannot appear in a filename on
# SMB or NTFS, so discs titled "Star Trek: Deep Space Nine" have to lose it.
name=$(tr -d '\000-\037/' <<<"$name" |
    sed -E 's/[:*?"<>|]/-/g; s/[[:space:]]+/ /g; s/^ +//; s/ +$//')

if [[ -z $name ]]; then
    echo "media-library-path: a name is required" >&2
    exit 2
fi

case $kind in
tv)
    printf '%s/tv/%s/Season %02d/%s - S%02dE%02d.mkv' \
        "$library" "$name" "$season" "$name" "$season" "$episode"
    ;;
movie)
    if ((position == 0)); then
        printf '%s/movies/%s/%s.mkv' "$library" "$name" "$name"
    else
        # Jellyfin reads an `extras` subdirectory as bonus content rather than
        # as alternate versions of the feature.
        printf '%s/movies/%s/extras/%s - Extra %02d.mkv' \
            "$library" "$name" "$name" "$position"
    fi
    ;;
*)
    echo "media-library-path: --kind must be movie or tv" >&2
    exit 2
    ;;
esac
