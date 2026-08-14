# shellcheck shell=bash
# gw-remove [branch] -- remove a worktree and prune empty parent dirs.
# Prints a safe directory to land in, for the shell wrapper to cd to.

force=0
args=()
for arg in "$@"; do
    case "$arg" in
    -f | --force) force=1 ;;
    -h | --help)
        cat >&2 <<'EOF'
usage: gw-remove [-f|--force] [branch]

Remove the worktree for [branch] (default: the current worktree), then
rmdir any parent directories the nested layout left empty.
EOF
        exit 0
        ;;
    *) args+=("$arg") ;;
    esac
done

root=$(gw_root)

if [ "${#args[@]}" -gt 0 ]; then
    branch="${args[0]}"
    path=$(gw_worktree_of_branch "$branch")
    [ -n "$path" ] || gw_die "no worktree checked out for branch: $branch"
else
    path=$(git rev-parse --path-format=absolute --show-toplevel 2>/dev/null) ||
        gw_die "not inside a worktree -- pass a branch name"
    [ "$path" != "$root" ] || gw_die "not inside a worktree -- pass a branch name"
fi

# Step out of the doomed directory before removing it: git commands run from a
# deleted cwd fail, which would otherwise break the landing-spot lookup below.
cd "$root"

if [ "$force" = 1 ]; then
    git worktree remove --force "$path" >&2
else
    git worktree remove "$path" >&2 || gw_die "worktree is dirty -- re-run with --force to discard"
fi
gw_msg "removed $path"

gw_prune_parents "$path" "$root"

# Land somewhere that still exists: a sibling worktree, else the root.
if landing=$(gw_donor_worktree "$path"); then
    printf '%s\n' "$landing"
else
    printf '%s\n' "$root"
fi
