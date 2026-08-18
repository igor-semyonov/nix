# shellcheck shell=bash
# gw-find [query] -- list every worktree under $GW_ROOT as "<host>/<owner>/<repo>
# <branch>\t<abs-path>", optionally filtered. Consumed by the gwc shell function.

query="${1:-}"

# Every collection root is a dir containing .bare/. -H so hidden dirs are seen.
while IFS= read -r bare; do
    root=$(dirname "$bare")
    rel="${root#"$GW_ROOT"/}"

    while IFS= read -r wt; do
        [ -d "$wt" ] || continue
        branch="${wt#"$root"/}"
        [ "$branch" != "$wt" ] || branch='(root)'
        line="$rel $branch"
        if [ -n "$query" ]; then
            case "$line" in
            *"$query"*) ;;
            *) continue ;;
            esac
        fi
        printf '%s\t%s\n' "$line" "$wt"
    done < <(git -C "$root" worktree list --porcelain 2>/dev/null | awk '
      /^worktree /{ w = substr($0, 10); b = 0 }
      /^bare$/    { b = 1 }
      /^$/        { if (w != "" && !b) print w; w = ""; b = 0 }
      END         { if (w != "" && !b) print w }')
done < <(fd --hidden --type directory --glob --absolute-path '.bare' "$GW_ROOT" 2>/dev/null | sed 's:/$::' | sort)
