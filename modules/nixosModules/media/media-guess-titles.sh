# Read a scan TSV on stdin, write the guessed title indices as CSV on stdout.
# Single definition of the heuristic, shared by rip-movie, rip-tv, rip-titles
# and the worker's unattended path.
#
# The guess is a starting point, not an answer: a double-length season finale
# and a two-episode "play all" have the same duration, so the disc alone cannot
# tell them apart. rip-tv presents this for confirmation rather than acting on
# it.

kind=movie
tolerance=${MEDIA_EPISODE_TOLERANCE:-25}

while (($#)); do
    case $1 in
    -k | --kind)
        kind=$2
        shift 2
        ;;
    --tolerance)
        tolerance=$2
        shift 2
        ;;
    *)
        echo "media-guess-titles: unknown argument: $1" >&2
        exit 2
        ;;
    esac
done

case $kind in
movie)
    # A feature disc pads itself with trailers, idents and playlist decoys;
    # the film is simply the longest thing on it.
    awk -F'\t' '
        $1 == "TITLE" && $3 > best { best = $3; id = $2 }
        END { if (best > 0) print id }
    '
    ;;
tv)
    # Episodes cluster around their own median. The "play all" title is a
    # concatenation and lands well above it, featurettes well below. Anything
    # at a clean multiple of the median is ambiguous by construction and is
    # deliberately left out of the guess for a human to rule on.
    awk -F'\t' -v tol="$tolerance" '
        # n must start as a number: awk subscripts stringify, so an
        # uninitialised n indexes id[""] rather than id[0] and loses a title.
        BEGIN { n = 0 }
        $1 == "TITLE" { id[n] = $2; secs[n] = $3; sorted[n] = $3; n++ }
        END {
            if (n == 0) exit
            for (i = 1; i < n; i++) {
                x = sorted[i]; j = i - 1
                while (j >= 0 && sorted[j] > x) { sorted[j + 1] = sorted[j]; j-- }
                sorted[j + 1] = x
            }
            median = (n % 2) ? sorted[int(n / 2)] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2
            low = median * (100 - tol) / 100
            high = median * (100 + tol) / 100
            out = ""
            for (i = 0; i < n; i++)
                if (secs[i] >= low && secs[i] <= high) out = (out == "" ? id[i] : out "," id[i])
            print out
        }
    '
    ;;
*)
    echo "media-guess-titles: --kind must be movie or tv" >&2
    exit 2
    ;;
esac
