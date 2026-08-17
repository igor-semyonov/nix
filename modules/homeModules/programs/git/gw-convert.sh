# shellcheck shell=bash
# gw-convert [path] -- relocate a normal clone under $GW_ROOT and convert it into
# the bare + worktree layout, preserving the current branch and any untracked
# files. Prints the path of the resulting checkout.

no_move=0
target=""
for arg in "$@"; do
    case "$arg" in
    --no-move) no_move=1 ;;
    -h | --help)
        cat >&2 <<'EOF'
usage: gw-convert [--no-move] [path]

Convert the normal clone at [path] (default: the current repo's toplevel) into a
worktree collection:
  <root>/.bare/     the moved .git directory, marked bare
  <root>/.git       gitfile pointing at .bare
  <root>/<branch>/  the existing checkout, files and all

By default <root> is the location gw-clone would have used,
$GW_ROOT/<host>/<owner>/<repo>, derived from origin's URL -- the clone is moved
there first. --no-move converts in place, leaving <root> where the clone is.

Refuses to run on a repo that already has multiple worktrees or submodules.
EOF
        exit 0
        ;;
    -*) gw_die "unknown argument: $arg" ;;
    *)
        [ -z "$target" ] || gw_die "unexpected extra argument: $arg"
        target="$arg"
        ;;
    esac
done

if [ -n "$target" ]; then
    cd "$target" || gw_die "no such directory: $target"
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
# An unborn HEAD (fresh init, or a clone whose remote HEAD was missing) names a
# branch that has no commit, so `git worktree add` cannot check it out. Catch it
# before moving or converting anything.
git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null ||
    gw_die "branch '$branch' has no commits yet -- commit something first"

# Relocate to where gw-clone would have put this repo, so every collection lives
# under $GW_ROOT with the same host/owner/repo layout. Done before any surgery:
# a plain `mv` of an untouched clone is trivially recoverable, and bailing here
# leaves the repo exactly as found.
if [ "$no_move" = 0 ]; then
    origin_url=$(git config --get remote.origin.url || true)
    [ -n "$origin_url" ] ||
        gw_die "no origin remote to derive a location from -- re-run with --no-move"

    gw_parse_url "$origin_url"
    dest="$GW_ROOT/$GW_HOST/$GW_OWNER/$GW_REPO"

    if [ "$dest" = "$toplevel" ]; then
        gw_msg "already at $dest"
    else
        [ ! -e "$dest" ] || gw_die "destination already exists: $dest"
        case "$dest/" in
        "$toplevel"/*) gw_die "destination $dest is inside the repo being moved" ;;
        esac

        gw_msg "moving $toplevel -> $dest"
        mkdir -p "$(dirname "$dest")"
        # Across filesystems mv copies then deletes; a failure can leave a partial
        # destination, so clear it rather than converting half a repo.
        mv -- "$toplevel" "$dest" || {
            rm -rf -- "$dest"
            gw_die "failed to move $toplevel -> $dest"
        }
        # Only tidy up inside $GW_ROOT. Elsewhere the parents are the user's own
        # directory layout, not ours to remove.
        case "$toplevel/" in
        "$GW_ROOT"/*) gw_prune_parents "$toplevel" "$GW_ROOT" ;;
        esac

        toplevel="$dest"
        cd "$toplevel" || gw_die "cannot enter $toplevel"
    fi
fi

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
