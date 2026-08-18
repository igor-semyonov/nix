# shellcheck shell=bash
# Shared helpers for the gw-* scripts. Prepended to each by package.nix.
# Convention: human-readable output goes to stderr, machine-readable paths to
# stdout, so the shell wrappers can `cd "$(gw-add ...)"`.
#
# Configuration comes from the environment so the scripts stay pure packages:
#   GW_ROOT           base dir holding worktree collections (required)
#   GW_SYMLINK_FILES  colon-separated untracked files shared across worktrees,
#                     via the per-collection .gw-shared/ store
#   GW_COPY_FILES     colon-separated untracked files to copy into new worktrees
#   GW_DIRENV_ALLOW   1 to run `direnv allow` in a new worktree with an .envrc
#   GW_DIRENV_CACHE   1 to copy an existing worktree's .direnv cache into a new
#                     one, so the devShell is not re-evaluated per branch
#
# Per-collection overrides live in the collection's own git config; see
# gw_resolve_lists below (gw.symlink / gw.copy / gw.inherit).

gw_msg() { printf '%s\n' "$*" >&2; }
gw_die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

: "${GW_ROOT:=$HOME/src}"
: "${GW_SYMLINK_FILES=}"
: "${GW_COPY_FILES=.env:.env.local}"
: "${GW_DIRENV_ALLOW:=1}"
: "${GW_DIRENV_CACHE:=1}"

# Name of the per-collection store for shared untracked files. Lives beside
# .bare/, so it is outside every worktree and cannot be removed by gw-remove.
gw_shared_dir=.gw-shared

# Per-repo overrides live in the collection's own git config (.bare/config), so
# they are untracked, travel with the repo, and need no new file format:
#   git config --add gw.symlink .secrets     # shared across branches
#   git config --add gw.copy    .env         # private per branch
#   git config gw.inherit false              # seed nothing at all
# A repo that sets gw.symlink/gw.copy REPLACES the corresponding global list
# rather than adding to it, so a repo can opt out of a global entry.
gw_config_list() {
    git config --get-all "$1" 2>/dev/null || true
}

# Resolve the effective symlink/copy lists for the collection $1 is in, filling
# gw_symlink_files / gw_copy_files. Falls back to the GW_* environment defaults.
gw_resolve_lists() {
    local dir="$1" inherit repo_list
    IFS=':' read -r -a gw_symlink_files <<<"$GW_SYMLINK_FILES"
    IFS=':' read -r -a gw_copy_files <<<"$GW_COPY_FILES"

    inherit=$(git -C "$dir" config --get gw.inherit 2>/dev/null || true)
    if [ "$inherit" = false ]; then
        gw_symlink_files=()
        gw_copy_files=()
        return 0
    fi

    if repo_list=$(gw_config_list gw.symlink) && [ -n "$repo_list" ]; then
        mapfile -t gw_symlink_files <<<"$repo_list"
    fi
    if repo_list=$(gw_config_list gw.copy) && [ -n "$repo_list" ]; then
        mapfile -t gw_copy_files <<<"$repo_list"
    fi
}

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

# Absolute path of the collection's shared-file store, created on demand.
# Sits beside .bare/, so it outlives every individual worktree. $1 is any path
# inside the collection.
gw_shared_path() {
    local common dir
    common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
    [ "$(basename "$common")" = ".bare" ] || return 1
    dir="$(dirname "$common")/$gw_shared_dir"
    mkdir -p "$dir"
    # Shared secrets live here; keep them owner-only.
    chmod 700 "$dir" 2>/dev/null || true
    printf '%s\n' "$dir"
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

# First worktree other than $2 that actually contains the relative path $1.
# gw_donor_worktree only returns *some* worktree, which is not enough for
# seeding: the file being sought may live in any one of them.
gw_worktree_with() {
    local name="$1" exclude="$2" wt
    while IFS= read -r wt; do
        [ "$wt" != "$exclude" ] || continue
        if [ -e "$wt/$name" ]; then
            printf '%s\n' "$wt"
            return 0
        fi
    done < <(gw_worktrees)
    return 1
}

# Seed a fresh worktree with untracked dev files, then allow direnv.
#
# Symlinked entries point at the collection's $gw_shared_dir, which sits beside
# .bare/ and so survives `gw-remove` of any worktree -- linking worktree-to-
# worktree would dangle as soon as the donor was removed. A file found only in a
# donor is migrated into the shared dir on first use, so existing collections
# adopt the layout without manual work.
#
# Copied entries still come from a donor: they are meant to diverge per worktree,
# so there is nothing to centralise. A tracked .envrc needs no seeding -- git
# already checked it out -- but still needs allowing, so that runs regardless.
# Existing files are never overwritten.
gw_inherit() {
    local dst="$1" donor="$2" name src shared from
    shared=""
    # Only materialise the shared store when something actually wants it, so
    # collections that symlink nothing stay free of an empty directory.
    if [ -n "${gw_symlink_files[*]-}" ]; then
        shared=$(gw_shared_path "$dst") || shared=""
    fi

    if [ -n "$shared" ]; then
        for name in "${gw_symlink_files[@]+${gw_symlink_files[@]}}"; do
            [ -n "$name" ] || continue
            src="$shared/$name"
            # Adopt a pre-existing copy into the shared store once, from whichever
            # worktree happens to hold it, and leave a link behind in its place.
            if [ ! -e "$src" ] && from=$(gw_worktree_with "$name" "$dst"); then
                mkdir -p "$(dirname "$src")"
                mv -- "$from/$name" "$src"
                ln -srn "$src" "$from/$name"
                gw_msg "  moved $name into $gw_shared_dir/ (now shared)"
            fi
            if [ -e "$src" ] && [ ! -e "$dst/$name" ]; then
                mkdir -p "$(dirname "$dst/$name")"
                ln -srn "$src" "$dst/$name"
                gw_msg "  linked $name"
            fi
        done
    fi

    for name in "${gw_copy_files[@]+${gw_copy_files[@]}}"; do
        [ -n "$name" ] || continue
        # Prefer the nominated donor, but fall back to any worktree that has it.
        if [ -n "$donor" ] && [ -e "$donor/$name" ]; then
            src="$donor/$name"
        elif from=$(gw_worktree_with "$name" "$dst"); then
            src="$from/$name"
        else
            continue
        fi
        if [ ! -e "$dst/$name" ]; then
            mkdir -p "$(dirname "$dst/$name")"
            cp -a "$src" "$dst/$name"
            gw_msg "  copied $name"
        fi
    done

    # Before `direnv allow`, so the first evaluation already sees a warm cache.
    if [ "$GW_DIRENV_CACHE" = 1 ]; then
        if [ -n "$donor" ] && [ -d "$donor/.direnv" ]; then
            gw_copy_direnv "$dst" "$donor"
        elif from=$(gw_worktree_with .direnv "$dst"); then
            gw_copy_direnv "$dst" "$from"
        fi
    fi

    if [ "$GW_DIRENV_ALLOW" = 1 ] && [ -e "$dst/.envrc" ] && command -v direnv >/dev/null 2>&1; then
        (cd "$dst" && direnv allow) && gw_msg "  direnv allow"
    fi
}

# Copy the .direnv cache from an existing worktree into the new one, so a fresh
# branch reuses the evaluated devShell instead of rebuilding it.
#
# nix-direnv keys its cache on a hash of the flake expression (usually just "."),
# NOT on the worktree path, so the filenames match across worktrees. It then
# invalidates on mtime: the cache is stale if any watched file (flake.nix,
# flake.lock, .envrc) is newer than the profile .rc. `git worktree add` has just
# written those files with current mtimes, so a copied cache always looks stale
# until its own timestamps are bumped past them -- hence the `touch -h`, which is
# exactly what nix-direnv itself does after a reload.
#
# Skipped when flake.nix/flake.lock differ between the two worktrees: the cache
# would be evaluated for the wrong inputs, and direnv would rebuild anyway.
gw_copy_direnv() {
    local dst="$1" src="$2" f

    [ -n "$src" ] || return 0
    [ -d "$src/.direnv" ] || return 0
    [ ! -e "$dst/.direnv" ] || return 0
    # Nothing to reuse without an .envrc in the new worktree.
    [ -e "$dst/.envrc" ] || return 0

    for f in flake.nix flake.lock; do
        if [ -e "$src/$f" ] || [ -e "$dst/$f" ]; then
            cmp -s "$src/$f" "$dst/$f" || {
                gw_msg "  .direnv not reused ($f differs)"
                return 0
            }
        fi
    done

    cp -a "$src/.direnv" "$dst/.direnv" || return 0
    # -h so the flake-profile symlink into /nix/store is stamped, not its target.
    touch -h "$dst"/.direnv/flake-profile-* "$dst"/.direnv/nix-profile-* \
        "$dst"/.direnv/flake-inputs/* 2>/dev/null || true
    gw_msg "  reused .direnv cache"
}

# Add a worktree for branch $1 (base $2 when the branch is new). Prints its path.
# Existing local branch -> check out; remote-only -> track it; neither -> create.
gw_add_worktree() {
    local branch="$1" base="${2:-}" root path existing donor
    gw_assert_branch_name "$branch"
    root=$(gw_root)
    path="$root/$branch"
    gw_resolve_lists "$root"

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
