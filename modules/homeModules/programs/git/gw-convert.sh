# shellcheck shell=bash
# gw-convert [path] -- convert a normal clone in place into the bare + worktree
# layout, preserving the current branch and any untracked files.
# Prints the path of the resulting checkout.

if [ "${1:-}" = -h ] || [ "${1:-}" = --help ]; then
    cat >&2 <<'EOF'
usage: gw-convert [path]

Convert the normal clone at [path] (default: the current repo's toplevel) into:
  <path>/.bare/     the moved .git directory, marked bare
  <path>/.git       gitfile pointing at .bare
  <path>/<branch>/  the existing checkout, files and all

Refuses to run on a repo that already has multiple worktrees or submodules.
EOF
    exit 0
fi

if [ -n "${1:-}" ]; then
    cd "$1" || gw_die "no such directory: $1"
fi

toplevel=$(git rev-parse --path-format=absolute --show-toplevel 2>/dev/null) ||
    gw_die "not inside a git repository"
gitdir=$(git rev-parse --path-format=absolute --git-dir)
common=$(git rev-parse --path-format=absolute --git-common-dir)

[ "$(basename "$common")" != ".bare" ] || gw_die "already a worktree collection"
[ "$gitdir" = "$common" ] || gw_die "run this from the primary worktree, not a linked one"
[ "$gitdir" = "$toplevel/.git" ] || gw_die "unexpected .git location: $gitdir"
[ "$(git rev-parse --is-bare-repository)" = false ] || gw_die "repository is already bare"

# One worktree only: converting with linked worktrees around would strand them.
if [ "$(gw_worktrees | wc -l)" -gt 1 ]; then
    gw_die "repository has linked worktrees already -- remove them first"
fi
# Submodule .git files point back at the old gitdir path; not worth rewriting.
if [ -f "$toplevel/.gitmodules" ]; then
    gw_die "repository has submodules -- convert manually"
fi

branch=$(git symbolic-ref --quiet --short HEAD) ||
    gw_die "HEAD is detached -- check out a branch first"

gw_msg "converting $toplevel (branch $branch)"

cd "$toplevel"
staging=".gw-convert-staging.$$"
[ ! -e "$staging" ] || gw_die "staging dir already exists: $staging"

# Move the working tree aside, turn .git into .bare, then re-check-out the branch
# into its nested directory and restore the saved files on top.
mkdir "$staging"
for entry in * .[^.]* ..?*; do
    case "$entry" in
    '*' | '.[^.]*' | '..?*' | .git | "$staging") continue ;;
    esac
    mv -- "$entry" "$staging/"
done

mv .git .bare
git --git-dir=./.bare config core.bare true
printf 'gitdir: ./.bare\n' >.git

# --force: HEAD in the now-bare repo still names $branch, which would otherwise
# trip the "already checked out" guard.
git worktree add --force "$toplevel/$branch" "$branch" >&2

# Restore untracked/ignored leftovers, without clobbering checked-out files.
shopt -s dotglob nullglob
for entry in "$staging"/*; do
    name=$(basename "$entry")
    if [ -e "$toplevel/$branch/$name" ] && [ ! -d "$entry" ]; then
        rm -f -- "$entry"
        continue
    fi
    mv -n -- "$entry" "$toplevel/$branch/" 2>/dev/null || true
done
shopt -u dotglob nullglob
rm -rf -- "$staging"

# A repo cloned normally may also lack the remotes refspec (e.g. --single-branch).
if [ -n "$(git config --get remote.origin.url || true)" ]; then
    git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
    git fetch --prune --quiet origin || gw_msg "warning: fetch failed, refs may be stale"
    git remote set-head origin --auto >/dev/null 2>&1 || true
fi

gw_msg "done: $toplevel/$branch"
printf '%s\n' "$toplevel/$branch"
