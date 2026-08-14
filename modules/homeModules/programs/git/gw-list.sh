# shellcheck shell=bash
# gw-list -- worktrees in the current collection, with branch, upstream and dirt.

root=$(gw_root)
printf 'collection: %s\n' "$root"

while IFS= read -r wt; do
    rel="${wt#"$root"/}"
    [ "$rel" != "$wt" ] || rel='.'

    branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null || echo '(detached)')
    track=$(git -C "$wt" for-each-ref --format='%(upstream:short)%(upstream:track)' \
        "refs/heads/$branch" 2>/dev/null || true)

    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
        dirty='*'
    else
        dirty=' '
    fi

    printf '%s %-28s %-28s %s\n' "$dirty" "$rel" "$branch" "$track"
done < <(gw_worktrees)
