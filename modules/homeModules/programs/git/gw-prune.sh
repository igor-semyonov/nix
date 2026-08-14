# shellcheck shell=bash
# gw-prune -- prune stale worktree entries and offer to remove worktrees whose
# upstream branch is gone (the merged-PR cleanup case).

dry_run=0
assume_yes=0
for arg in "$@"; do
    case "$arg" in
    -n | --dry-run) dry_run=1 ;;
    -y | --yes) assume_yes=1 ;;
    -h | --help)
        cat >&2 <<'EOF'
usage: gw-prune [-n|--dry-run] [-y|--yes]

Fetch with --prune, drop stale worktree admin entries, then remove clean
worktrees whose upstream branch no longer exists on the remote.
Dirty worktrees are always kept.
EOF
        exit 0
        ;;
    *) gw_die "unknown argument: $arg" ;;
    esac
done

root=$(gw_root)

git fetch --prune --quiet origin 2>/dev/null || gw_msg "warning: fetch failed, using local refs"
git worktree prune
gw_msg "pruned stale worktree entries"

removed=0
while IFS= read -r wt; do
    branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null) || continue

    track=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$branch")
    [ "$track" = '[gone]' ] || continue

    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
        gw_msg "keeping $branch (upstream gone, but worktree is dirty)"
        continue
    fi

    if [ "$dry_run" = 1 ]; then
        gw_msg "would remove $wt ($branch, upstream gone)"
        continue
    fi

    if [ "$assume_yes" != 1 ]; then
        printf 'remove %s (%s, upstream gone)? [y/N] ' "$wt" "$branch" >&2
        read -r reply </dev/tty || reply=n
        case "$reply" in
        y | Y) ;;
        *)
            gw_msg "keeping $branch"
            continue
            ;;
        esac
    fi

    git worktree remove "$wt" >&2 || continue
    gw_prune_parents "$wt" "$root"
    git branch -D "$branch" >/dev/null 2>&1 || true
    gw_msg "removed $wt"
    removed=$((removed + 1))
done < <(gw_worktrees)

[ "$removed" -gt 0 ] || gw_msg "nothing else to remove"
