# shellcheck shell=bash
# Shared helpers for the gw-* scripts. Prepended to each by package.nix.
# Convention: human-readable output goes to stderr, machine-readable paths to
# stdout, so the shell wrappers can `cd "$(gw-add ...)"`.
#
# Configuration comes from the environment so the scripts stay pure packages:
#   GW_ROOT           base dir holding worktree collections (required)
#   GW_SYMLINK_FILES  colon-separated untracked files to symlink into new worktrees
#   GW_COPY_FILES     colon-separated untracked files to copy into new worktrees
#   GW_DIRENV_ALLOW   1 to run `direnv allow` in a new worktree with an .envrc

gw_msg() { printf '%s\n' "$*" >&2; }
gw_die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

: "${GW_ROOT:=$HOME/src}"
: "${GW_SYMLINK_FILES=}"
: "${GW_COPY_FILES=.env:.env.local}"
: "${GW_DIRENV_ALLOW:=1}"

IFS=':' read -r -a gw_symlink_files <<<"$GW_SYMLINK_FILES"
IFS=':' read -r -a gw_copy_files <<<"$GW_COPY_FILES"

# Split a git remote URL into GW_HOST / GW_OWNER / GW_REPO.
# Local paths and file:// URLs have no host or owner, so they get the
# "local/<parent-dir>" placeholder to keep the layout depth uniform.
gw_parse_url() {
    local url="$1" path
    url="${url%/}"
    url="${url%.git}"
    case "$url" in
    file://*)
        path="${url#file://}"
        GW_HOST=local
        GW_OWNER=$(basename "$(dirname "$path")")
        GW_REPO=$(basename "$path")
        ;;
    /* | ./* | ../* | "$HOME"/*)
        GW_HOST=local
        GW_OWNER=$(basename "$(dirname "$url")")
        GW_REPO=$(basename "$url")
        ;;
    *://*) # scheme://[user@]host[:port]/owner/repo
        path="${url#*://}"
        path="${path#*@}"
        GW_HOST="${path%%/*}"
        GW_HOST="${GW_HOST%%:*}"
        path="${path#*/}"
        ;;
    *@*:*) # git@host:owner/repo
        path="${url#*@}"
        GW_HOST="${path%%:*}"
        path="${path#*:}"
        ;;
    *) gw_die "cannot parse remote URL: $1" ;;
    esac

    # Forge URLs still need owner/repo split out of the remaining path.
    if [ "$GW_HOST" != local ]; then
        path="${path#/}"
        if [ "$path" = "${path%/*}" ]; then
            gw_die "remote URL has no owner component: $1"
        fi
        GW_OWNER="${path%/*}"
        GW_REPO="${path##*/}"
    fi

    if [ -z "$GW_HOST" ] || [ -z "$GW_OWNER" ] || [ -z "$GW_REPO" ]; then
        gw_die "cannot parse remote URL: $1"
    fi
}

# Absolute path of the collection root: the dir holding .bare/ and the worktrees.
gw_root() {
    local common
    common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) ||
        gw_die "not inside a git repository"
    if [ "$(basename "$common")" != ".bare" ]; then
        gw_die "not a worktree collection (no .bare/ layout) -- run gwconvert here first"
    fi
    dirname "$common"
}

# Worktree paths in the current collection, excluding the bare entry.
gw_worktrees() {
    git worktree list --porcelain | awk '
    /^worktree /{ wt = substr($0, 10); bare = 0 }
    /^bare$/    { bare = 1 }
    /^$/        { if (wt != "" && !bare) print wt; wt = ""; bare = 0 }
    END         { if (wt != "" && !bare) print wt }'
}

# Path of the worktree holding branch $1, empty if it is not checked out.
gw_worktree_of_branch() {
    git worktree list --porcelain | awk -v want="refs/heads/$1" '
    /^worktree /{ wt = substr($0, 10) }
    /^branch /  { if (substr($0, 8) == want) { print wt; exit } }'
}

# Short name of the default branch, preferring origin's HEAD.
gw_default_branch() {
    local ref
    if ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); then
        printf '%s\n' "${ref#origin/}"
    elif ref=$(git symbolic-ref --quiet --short HEAD 2>/dev/null); then
        printf '%s\n' "$ref"
    else
        printf 'main\n'
    fi
}

gw_assert_branch_name() {
    git check-ref-format --branch "$1" >/dev/null 2>&1 ||
        gw_die "invalid branch name: $1"
}

# rmdir now-empty parents of $1, walking up but never past $2.
gw_prune_parents() {
    local dir="$1" root="$2"
    dir=$(dirname "$dir")
    while [ "$dir" != "$root" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        rmdir "$dir" 2>/dev/null || break
        dir=$(dirname "$dir")
    done
}

# First existing worktree that is not $1, to copy untracked dev files from.
gw_donor_worktree() {
    local exclude="$1" wt
    while IFS= read -r wt; do
        if [ "$wt" != "$exclude" ] && [ -d "$wt" ]; then
            printf '%s\n' "$wt"
            return 0
        fi
    done < <(gw_worktrees)
    return 1
}

# Seed a fresh worktree with untracked dev files (.env, .direnv, ...) from a
# donor, then allow direnv. A tracked .envrc needs no seeding -- git already
# checked it out -- but still needs allowing, so that runs with or without a
# donor. Existing files are never overwritten.
gw_inherit() {
    local dst="$1" donor="$2" name src
    if [ -n "$donor" ]; then
        for name in "${gw_symlink_files[@]+${gw_symlink_files[@]}}"; do
            [ -n "$name" ] || continue
            src="$donor/$name"
            if [ -e "$src" ] && [ ! -e "$dst/$name" ]; then
                mkdir -p "$(dirname "$dst/$name")"
                ln -srn "$src" "$dst/$name"
                gw_msg "  linked $name"
            fi
        done
        for name in "${gw_copy_files[@]+${gw_copy_files[@]}}"; do
            [ -n "$name" ] || continue
            src="$donor/$name"
            if [ -e "$src" ] && [ ! -e "$dst/$name" ]; then
                mkdir -p "$(dirname "$dst/$name")"
                cp -a "$src" "$dst/$name"
                gw_msg "  copied $name"
            fi
        done
    fi

    if [ "$GW_DIRENV_ALLOW" = 1 ] && [ -e "$dst/.envrc" ] && command -v direnv >/dev/null 2>&1; then
        (cd "$dst" && direnv allow) && gw_msg "  direnv allow"
    fi
}

# Add a worktree for branch $1 (base $2 when the branch is new). Prints its path.
# Existing local branch -> check out; remote-only -> track it; neither -> create.
gw_add_worktree() {
    local branch="$1" base="${2:-}" root path existing donor
    gw_assert_branch_name "$branch"
    root=$(gw_root)
    path="$root/$branch"

    existing=$(gw_worktree_of_branch "$branch")
    if [ -n "$existing" ]; then
        gw_msg "'$branch' is already checked out at $existing"
        printf '%s\n' "$existing"
        return 0
    fi
    if [ -e "$path" ]; then
        gw_die "path already exists: $path"
    fi

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$path" "$branch" >&2
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        git worktree add --track -b "$branch" "$path" "origin/$branch" >&2
    else
        [ -n "$base" ] || base="origin/$(gw_default_branch)"
        git rev-parse --verify --quiet "$base^{commit}" >/dev/null ||
            gw_die "base revision not found: $base"
        git worktree add --no-track -b "$branch" "$path" "$base" >&2
    fi

    donor=$(gw_donor_worktree "$path") || donor=""
    gw_inherit "$path" "$donor"
    printf '%s\n' "$path"
}
