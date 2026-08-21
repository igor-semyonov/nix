# shellcheck shell=bash
# gw-find [query]... -- list every worktree under $GW_ROOT as "<host>/<owner>/<repo>
# <branch>\t<abs-path>", optionally filtered. Consumed by the gwc shell function.

if [ "${1-}" = -h ] || [ "${1-}" = --help ]; then
    cat >&2 <<'EOF'
usage: gw-find [query]...

List every worktree under $GW_ROOT as "<host>/<owner>/<repo> <branch>\t<path>".

Each query is a case-sensitive substring of that "<repo-path> <branch>" text and
they are ANDed, so terms narrow independently of order:

  gw-find anduril            every worktree of every anduril repo
  gw-find anduril master     master in anduril-nixpkgs, not its every branch
EOF
    exit 0
fi

queries=("$@")

# Every collection root is a dir containing .bare/. -H so hidden dirs are seen.
while IFS= read -r bare; do
    root=$(dirname "$bare")
    rel="${root#"$GW_ROOT"/}"

    while IFS= read -r wt; do
        [ -d "$wt" ] || continue
        branch="${wt#"$root"/}"
        [ "$branch" != "$wt" ] || branch='(root)'
        line="$rel $branch"
        skip=0
        for query in "${queries[@]+${queries[@]}}"; do
            [ -n "$query" ] || continue
            case "$line" in
            *"$query"*) ;;
            *)
                skip=1
                break
                ;;
            esac
        done
        [ "$skip" = 0 ] || continue
        printf '%s\t%s\n' "$line" "$wt"
    done < <(git -C "$root" worktree list --porcelain 2>/dev/null | awk '
      /^worktree /{ w = substr($0, 10); b = 0 }
      /^bare$/    { b = 1 }
      /^$/        { if (w != "" && !b) print w; w = ""; b = 0 }
      END         { if (w != "" && !b) print w }')
done < <(fd --hidden --type directory --glob --absolute-path '.bare' "$GW_ROOT" 2>/dev/null | sed 's:/$::' | sort)
