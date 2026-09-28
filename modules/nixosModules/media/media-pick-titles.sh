# Interactive title picker. Reads a scan TSV on stdin, renders it with the
# guess pre-selected and the ambiguous titles called out, and writes the
# confirmed indices to stdout as CSV. All prompting goes to stderr and /dev/tty
# so stdout stays parseable.

guess=""
label=""
kind=movie
season=1
first_episode=1
single=false
name=""
library=""

while (($#)); do
    case $1 in
    -g | --guess)
        guess=$2
        shift 2
        ;;
    -l | --label)
        label=$2
        shift 2
        ;;
    -k | --kind)
        kind=$2
        shift 2
        ;;
    -s | --season)
        season=$2
        shift 2
        ;;
    -e | --first-episode)
        first_episode=$2
        shift 2
        ;;
    -n | --name)
        name=$2
        shift 2
        ;;
    --library)
        library=$2
        shift 2
        ;;
    --single)
        single=true
        shift
        ;;
    *)
        echo "media-pick-titles: unknown argument: $1" >&2
        exit 2
        ;;
    esac
done

scan=$(cat)

if [[ ! -r /dev/tty ]]; then
    echo "media-pick-titles: no terminal, accepting the guess ($guess)" >&2
    printf '%s' "$guess"
    exit 0
fi

# 0-3,7 -> 0,1,2,3,7. Order is preserved, so a descending range or an
# out-of-order list is how you fix episodes that rip in the wrong order.
expand_ranges() {
    local spec=$1 out="" part a b i
    local -a parts
    IFS=',' read -ra parts <<<"$spec"
    for part in "${parts[@]}"; do
        part=${part//[[:space:]]/}
        [[ -n $part ]] || continue
        if [[ $part =~ ^([0-9]+)-([0-9]+)$ ]]; then
            a=${BASH_REMATCH[1]}
            b=${BASH_REMATCH[2]}
            if ((a <= b)); then
                for ((i = a; i <= b; i++)); do out+="${out:+,}$i"; done
            else
                for ((i = a; i >= b; i--)); do out+="${out:+,}$i"; done
            fi
        elif [[ $part =~ ^[0-9]+$ ]]; then
            out+="${out:+,}$part"
        else
            return 1
        fi
    done
    printf '%s' "$out"
}

known_indices=$(awk -F'\t' '$1 == "TITLE" { print $2 }' <<<"$scan")

valid_selection() {
    local sel=$1 i
    [[ -n $sel ]] || return 1
    for i in ${sel//,/ }; do
        grep -qxF "$i" <<<"$known_indices" || {
            echo "  no title $i on this disc" >&2
            return 1
        }
    done
    if [[ $single == true && $sel == *,* ]]; then
        echo "  pick a single title" >&2
        return 1
    fi
}

duration_of() {
    awk -F'\t' -v want="$1" '$1 == "TITLE" && $2 == want { print $4 }' <<<"$scan"
}

render_table() {
    awk -F'\t' -v guess="$guess" -v kind="$kind" '
        BEGIN {
            n = 0
            split(guess, g, ",")
            for (i in g) chosen[g[i]] = 1
        }
        $1 == "TITLE" {
            id[n] = $2; secs[n] = $3; dur[n] = $4; chap[n] = $5; size[n] = $6
            sorted[n] = $3; n++
        }
        END {
            if (n == 0) { print "  (no titles)"; exit }
            for (i = 1; i < n; i++) {
                x = sorted[i]; j = i - 1
                while (j >= 0 && sorted[j] > x) { sorted[j + 1] = sorted[j]; j-- }
                sorted[j + 1] = x
            }
            median = (n % 2) ? sorted[int(n / 2)] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2

            printf "  %-3s %5s %10s %8s %10s %10s  %s\n", "", "idx", "duration", "chapters", "size", "vs median", "note"
            for (i = 0; i < n; i++) {
                mark = (id[i] in chosen) ? "[*]" : "[ ]"
                mult = (median > 0) ? secs[i] / median : 0

                # A play-all is the concatenation of everything below it, so it
                # matches the sum of the shorter titles. A genuinely long
                # episode does not -- which is the only thing that separates a
                # double-length finale from a two-episode play-all.
                # Needs at least two shorter titles and real extra length:
                # otherwise a title trivially "matches" the single slightly
                # shorter one next to it.
                shorter = 0
                fewer = 0
                for (k = 0; k < n; k++) if (secs[k] < secs[i]) { shorter += secs[k]; fewer++ }

                note = ""
                if (kind == "tv") {
                    if (fewer >= 2 && mult >= 1.7 && secs[i] >= shorter * 0.95 && secs[i] <= shorter * 1.05)
                        note = "play-all? runs as long as the shorter titles combined"
                    else if (mult >= 1.7)
                        note = "long -- double-length episode, or a partial play-all"
                    else if (mult <= 0.6)
                        note = "short -- extra or featurette?"
                } else if (!(id[i] in chosen) && mult <= 0.6) {
                    note = "short -- trailer or extra?"
                }

                printf "  %-3s %5d %10s %8s %10s %9.2fx  %s\n", \
                    mark, id[i], dur[i], chap[i], size[i], mult, note
            }
        }
    ' <<<"$scan"
}

# Shows the destination each title will be written to, so a mistyped name or a
# wrong episode offset is caught here rather than after hours of encoding.
preview() {
    local sel=$1 i=0 index dest
    for index in ${sel//,/ }; do
        if [[ $kind == tv ]]; then
            dest=$(media-library-path --kind tv --library "$library" --name "$name" \
                --season "$season" --episode "$((first_episode + i))")
        else
            dest=$(media-library-path --kind movie --library "$library" --name "$name" \
                --position "$i")
        fi
        printf '  title %-3s %-9s -> %s\n' "$index" "$(duration_of "$index")" "$dest"
        i=$((i + 1))
    done
}

selection=$guess
while :; do
    {
        printf '\nDisc: %s\n\n' "${label:-unknown}"
        render_table
        printf '\n'
        if [[ $single == true ]]; then
            printf 'Title to rip. Enter accepts the guess.\n'
        else
            printf 'Episodes in broadcast order, comma separated; ranges like 0-3 are fine.\n'
            printf 'Order matters -- it is what maps titles onto episode numbers.\n'
        fi
        printf 'Selection [%s]: ' "$selection"
    } >&2

    read -r reply </dev/tty || reply=""
    [[ -n $reply ]] || reply=$selection

    if ! candidate=$(expand_ranges "$reply"); then
        echo "  could not parse '$reply'" >&2
        continue
    fi
    valid_selection "$candidate" || continue

    {
        printf '\n'
        preview "$candidate"
        printf '\nProceed? [Y/n/e] '
    } >&2
    read -r confirm </dev/tty || confirm=""
    case ${confirm,,} in
    "" | y | yes)
        printf '%s' "$candidate"
        exit 0
        ;;
    n | no)
        echo "media-pick-titles: cancelled" >&2
        exit 1
        ;;
    *)
        selection=$candidate
        ;;
    esac
done
