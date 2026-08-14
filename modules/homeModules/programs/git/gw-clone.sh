# shellcheck shell=bash
# gw-clone <url> -- bare-clone into $GW_ROOT/<host>/<owner>/<repo>, prepare the
# worktree layout, check out the default branch. Prints the checkout path.

if [ $# -eq 0 ] || [ "$1" = -h ] || [ "$1" = --help ]; then
    cat >&2 <<'EOF'
usage: gw-clone <url> [branch]

Clone <url> as a worktree collection:
  $GW_ROOT/<host>/<owner>/<repo>/
  |-- .bare/    bare object store
  |-- .git      gitfile pointing at .bare
  `-- <branch>/ checkout of the default branch (or [branch])
EOF
    [ $# -eq 0 ] && exit 1
    exit 0
fi

url="$1"
want_branch="${2:-}"

gw_parse_url "$url"
root="$GW_ROOT/$GW_HOST/$GW_OWNER/$GW_REPO"

[ -e "$root" ] && gw_die "already exists: $root"

gw_msg "cloning $url -> $root"
mkdir -p "$root"

# Clean up a partial clone so a failed run does not leave a broken collection.
gw_clone_cleanup() {
    local status=$?
    if [ "$status" -ne 0 ] && [ ! -e "$root/.git" ]; then
        rm -rf -- "$root"
    fi
    exit "$status"
}
trap gw_clone_cleanup EXIT

git clone --bare "$url" "$root/.bare" >&2

# `git clone --bare` sets no fetch refspec, so every remote branch lands in
# refs/heads/* and origin/* never exists. Fix that before the first fetch.
git --git-dir="$root/.bare" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
printf 'gitdir: ./.bare\n' >"$root/.git"

cd "$root"
git fetch --prune --quiet origin
git remote set-head origin --auto >/dev/null 2>&1 || true

[ -n "$want_branch" ] || want_branch=$(gw_default_branch)

# The bare clone also left a local branch for every remote one, untracked. Drop
# all but the one about to be checked out, so later `gw-add <branch>` sees a
# remote-only branch and sets up tracking instead of branching from nowhere.
while IFS= read -r stale; do
    [ "$stale" != "$want_branch" ] || continue
    git branch --quiet --delete --force "$stale" >/dev/null 2>&1 || true
done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

# The bare clone's HEAD already points at the default branch, so the first
# checkout of it needs --force to bypass the "already checked out" guard.
if [ "$want_branch" = "$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" ]; then
    git worktree add --force "$root/$want_branch" "$want_branch" >&2
    path="$root/$want_branch"
    # The clone left this branch without an upstream; wire it up so status,
    # pull and push behave like they would in a normal clone.
    if git show-ref --verify --quiet "refs/remotes/origin/$want_branch"; then
        git branch --quiet --set-upstream-to="origin/$want_branch" "$want_branch" 2>/dev/null || true
    fi
    # No donor exists yet -- this is the first worktree -- but a tracked .envrc
    # still needs allowing, which gw_inherit handles.
    gw_inherit "$path" ""
else
    path=$(gw_add_worktree "$want_branch")
fi

gw_msg "done: $path"
printf '%s\n' "$path"
