# shellcheck shell=bash
# gw-pr <number> -- check a GitHub PR out into its own worktree. Prints the path.

if [ $# -eq 0 ] || [ "$1" = -h ] || [ "$1" = --help ]; then
    cat >&2 <<'EOF'
usage: gw-pr <number>

Fetch GitHub PR <number> into a worktree at <collection-root>/pr/<number>,
on a local branch pr/<number> tracking the PR head.
EOF
    [ $# -eq 0 ] && exit 1
    exit 0
fi

case "$1" in
'' | *[!0-9]*) gw_die "PR number must be numeric: $1" ;;
esac

num="$1"
branch="pr/$num"
root=$(gw_root)
path="$root/$branch"

existing=$(gw_worktree_of_branch "$branch")
if [ -n "$existing" ]; then
    gw_msg "PR #$num is already checked out at $existing"
    printf '%s\n' "$existing"
    exit 0
fi
[ ! -e "$path" ] || gw_die "path already exists: $path"

gw_msg "fetching PR #$num"
git fetch --quiet origin "pull/$num/head:$branch" ||
    gw_die "could not fetch PR #$num from origin"

git worktree add "$path" "$branch" >&2

donor=$(gw_donor_worktree "$path") || donor=""
gw_inherit "$path" "$donor"

gw_msg "done: $path"
printf '%s\n' "$path"
