# shellcheck shell=bash
# Shared helpers for the gw-* scripts. Prepended to each by package.nix.
# Convention: human-readable output goes to stderr, machine-readable paths to
# stdout, so the shell wrappers can `cd "$(gw-add ...)"`.
#
# Configuration comes from the environment so the scripts stay pure packages:
#   GW_ROOT           base dir holding worktree collections (required)
#   GW_DIRENV_ALLOW   1 to run `direnv allow` in a new worktree with an .envrc
#   GW_DIRENV_CACHE   1 to copy an existing worktree's .direnv cache into a new
#                     one, so the devShell is not re-evaluated per branch
#
# Which untracked files a new worktree inherits is per-collection state, not a
# global preference, so it lives in the collection's own git config rather than
# the environment. Manage it with `gw-share` and `gw-copy`; see
# gw_resolve_lists below.

gw_msg() { printf '%s\n' "$*" >&2; }
gw_die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

: "${GW_ROOT:=$HOME/src}"
: "${GW_DIRENV_ALLOW:=1}"
: "${GW_DIRENV_CACHE:=1}"

# Name of the per-collection store for shared untracked files. Lives beside
# .bare/, so it is outside every worktree and cannot be removed by gw-remove.
gw_shared_dir=.gw-shared

# Config keys holding the inherited-file lists, in the collection's .bare/config:
#   gw.symlink  one real file in .gw-shared/, symlinked into every worktree
#   gw.copy     copied per worktree, so each branch's version can diverge
gw_symlink_key=gw.symlink
gw_copy_key=gw.copy

# All values of a multi-valued config key, deduplicated. `git config --add`
# happily stores the same value twice, so dedupe here rather than making every
# caller defend against doing the work twice.
gw_config_list() {
    git -C "$1" config --get-all "$2" 2>/dev/null | awk 'NF && !seen[$0]++' || true
}

# Add $3 to key $2 unless already present, so repeated adds are a no-op.
gw_config_add() {
    local dir="$1" key="$2" value="$3"
    if git -C "$dir" config --get-all --fixed-value "$key" "$value" >/dev/null 2>&1; then
        return 1
    fi
    git -C "$dir" config --add "$key" "$value"
}

# Drop every copy of $3 from key $2. Returns 1 when it was not configured.
# --unset-all, not --unset: with duplicates present the latter refuses outright.
gw_config_remove() {
    local dir="$1" key="$2" value="$3"
    git -C "$dir" config --unset-all --fixed-value "$key" "$value" 2>/dev/null
}

# Resolve the collection's inherited-file lists into gw_symlink_files /
# gw_copy_files. $1 is any path inside the collection.
gw_resolve_lists() {
    local dir="$1" list
    gw_symlink_files=()
    gw_copy_files=()

    list=$(gw_config_list "$dir" "$gw_symlink_key")
    [ -z "$list" ] || mapfile -t gw_symlink_files <<<"$list"
    list=$(gw_config_list "$dir" "$gw_copy_key")
    [ -z "$list" ] || mapfile -t gw_copy_files <<<"$list"
}

gw_symlink_files=()
gw_copy_files=()

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

# Every worktree holding the relative path $1, one per line. Plural counterpart
# to gw_worktree_with, for commands that must reason about all copies at once --
# adopting a file that exists in several worktrees would destroy all but one.
gw_worktrees_with() {
    local name="$1" wt
    while IFS= read -r wt; do
        [ ! -e "$wt/$name" ] || printf '%s\n' "$wt"
    done < <(gw_worktrees)
}

# Reject anything that would escape the worktree or break the config encoding.
gw_assert_relpath() {
    local name="$1"
    case "$name" in
    "") gw_die "empty path" ;;
    /*) gw_die "path must be relative to the worktree root: $name" ;;
    *..*) gw_die "path must not contain '..': $name" ;;
    ./*) gw_die "drop the leading './': $name" ;;
    *) ;;
    esac
    # Trailing slashes make "$dir/$name" ambiguous for -e tests and ln targets.
    case "$name" in
    */) gw_die "drop the trailing '/': $name" ;;
    esac
}

# Refuse to manage a file git already owns: it would be checked out into every
# worktree anyway, and replacing it with a symlink shows up as a local
# modification. $1 is a worktree, $2 the relative path.
gw_assert_not_tracked() {
    local wt="$1" name="$2"
    if git -C "$wt" ls-files --error-unmatch -- "$name" >/dev/null 2>&1; then
        gw_die "$name is tracked by git -- it is already in every worktree"
    fi
}

# Warn when a path is not ignored: the seeded file or symlink will show up as
# untracked noise in `git status` for every worktree.
gw_warn_not_ignored() {
    local wt="$1" name="$2"
    git -C "$wt" check-ignore -q -- "$name" 2>/dev/null ||
        gw_msg "warning: $name is not gitignored; it will show as untracked"
}

# Link $1 from the shared store into every worktree that lacks it. Prints a line
# per worktree touched and returns the number linked via gw_propagated.
gw_propagate_symlink() {
    local name="$1" shared="$2" wt rel
    gw_propagated=0
    gw_skipped=0
    while IFS= read -r wt; do
        rel=${wt#"$(dirname "$shared")"/}
        if [ -e "$wt/$name" ] || [ -L "$wt/$name" ]; then
            gw_skipped=$((gw_skipped + 1))
            continue
        fi
        mkdir -p "$(dirname "$wt/$name")"
        ln -srn "$shared/$name" "$wt/$name"
        gw_msg "  linked into $rel"
        gw_propagated=$((gw_propagated + 1))
    done < <(gw_worktrees)
}

# Copy $1 from worktree $2 into every other worktree that lacks it.
gw_propagate_copy() {
    local name="$1" src="$2" root="$3" wt rel
    gw_propagated=0
    gw_skipped=0
    while IFS= read -r wt; do
        [ "$wt" != "$src" ] || continue
        rel=${wt#"$root"/}
        if [ -e "$wt/$name" ]; then
            gw_skipped=$((gw_skipped + 1))
            continue
        fi
        mkdir -p "$(dirname "$wt/$name")"
        cp -a "$src/$name" "$wt/$name"
        gw_msg "  copied into $rel"
        gw_propagated=$((gw_propagated + 1))
    done < <(gw_worktrees)
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
            if [ -e "$src" ]; then
                if [ ! -e "$dst/$name" ]; then
                    mkdir -p "$(dirname "$dst/$name")"
                    ln -srn "$src" "$dst/$name"
                    gw_msg "  linked $name"
                fi
            else
                # Configured but nowhere to be found: say so rather than doing
                # nothing silently, which reads as the feature being broken.
                gw_msg "  $name: shared but does not exist yet (nothing to link)"
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
            gw_msg "  $name: configured to copy but does not exist yet"
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

# Update refs/remotes/origin/$1 from origin. Best-effort: no origin, no network,
# or a branch that genuinely does not exist upstream all leave the local refs
# untouched and return non-zero, so callers can fall back to what is already
# fetched. Forced, matching the standard remotes refspec.
gw_fetch_branch() {
    local branch="$1"
    git config --get remote.origin.url >/dev/null 2>&1 || return 1
    git fetch --quiet origin "+refs/heads/$branch:refs/remotes/origin/$branch" 2>/dev/null
}

# Fast-forward local branch $1 to its upstream when it is strictly behind, so a
# worktree is not created from a stale ref. update-ref rather than a merge: the
# branch is not checked out anywhere yet, so there is no index or working tree.
gw_fast_forward() {
    local branch="$1" upstream old new short
    upstream=$(git for-each-ref --format='%(upstream)' "refs/heads/$branch")
    [ -n "$upstream" ] || return 0
    git show-ref --verify --quiet "$upstream" || return 0

    old=$(git rev-parse --verify "refs/heads/$branch")
    new=$(git rev-parse --verify "$upstream")
    [ "$old" != "$new" ] || return 0
    short="${upstream#refs/remotes/}"

    # Strictly behind only. A diverged branch carries local commits, and choosing
    # between merge, rebase and discard is the user's call, not ours.
    if ! git merge-base --is-ancestor "$old" "$new"; then
        gw_msg "  '$branch' has diverged from $short; leaving it where it is"
        return 0
    fi

    git update-ref -m "gw-add: fast-forward to $short" "refs/heads/$branch" "$new" "$old"
    gw_msg "  fast-forwarded '$branch' to $short"
}

# Add a worktree for branch $1 (base $2 when the branch is new). Prints its path.
# Existing local branch -> check out; remote-only -> track it; neither -> create.
gw_add_worktree() {
    local branch="$1" base="${2:-}" root path existing donor default
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

    # This is where a branch enters the collection, so its refs must be current.
    # Stale refs fail in two silent ways: a remote branch pushed since the last
    # fetch looks brand new and gets recreated empty from the default branch, and
    # a local branch left behind by an earlier fetch yields a worktree quietly
    # missing upstream commits. Skipped when a base is given -- that is an
    # explicit "branch from this revision", and needs no remote opinion.
    if [ -z "$base" ]; then
        gw_fetch_branch "$branch" || true
    fi

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        # A local branch with no upstream cannot be fast-forwarded and behaves
        # oddly under status/pull/push; adopt origin's counterpart when there is
        # one, which is what `git checkout <remote-only-branch>` would have done.
        if [ -z "$(git for-each-ref --format='%(upstream)' "refs/heads/$branch")" ] &&
            git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            git branch --quiet --set-upstream-to="origin/$branch" "$branch" 2>/dev/null || true
        fi
        gw_fast_forward "$branch"
        git worktree add "$path" "$branch" >&2
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        git worktree add --track -b "$branch" "$path" "origin/$branch" >&2
    else
        # A genuinely new branch: base it on current upstream, not on whatever
        # origin/HEAD happened to be at the last fetch, or it starts life behind.
        # A collection with no remote (or an unfetched one) has no origin/* to
        # branch from, so fall back to the local default branch, then HEAD.
        if [ -z "$base" ]; then
            default=$(gw_default_branch)
            gw_fetch_branch "$default" || true
            for base in "origin/$default" "$default" HEAD; do
                git rev-parse --verify --quiet "$base^{commit}" >/dev/null && break
            done
        fi
        git rev-parse --verify --quiet "$base^{commit}" >/dev/null ||
            gw_die "base revision not found: $base"
        git worktree add --no-track -b "$branch" "$path" "$base" >&2
    fi

    donor=$(gw_donor_worktree "$path") || donor=""
    gw_inherit "$path" "$donor"
    printf '%s\n' "$path"
}
