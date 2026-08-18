# shellcheck shell=bash
# gw-copy -- manage untracked files copied into each new worktree, for content
# that should diverge per branch (a .env pointing at a per-branch database, say).
#
# Unlike gw-share there is no central store: each worktree owns its copy, and
# editing one does not affect the others.

gw_copy_usage() {
    cat >&2 <<'EOF'
usage: gw-copy [list]
       gw-copy add <path>...
       gw-copy rm <path>...
       gw-copy sync [--from <branch>]

Files copied into each new worktree, diverging per branch.

  list   configured paths and which worktrees hold them (default)
  add    record the path, then copy it into worktrees that lack it
  rm     forget the path; existing files are left untouched
  sync   copy into any worktree still missing a configured path

Paths are relative to the worktree root. Existing files are never overwritten.
Use gw-share instead for one shared file (secrets, caches).
EOF
}

gw_copy_list() {
    local root name wt rel
    root=$(gw_root)
    gw_resolve_lists "$root"

    if [ "${#gw_copy_files[@]}" -eq 0 ]; then
        printf 'no copied files configured\n' >&2
        printf 'add one with: gw-copy add <path>\n' >&2
        return 0
    fi

    for name in "${gw_copy_files[@]}"; do
        printf '%s\n' "$name"
        while IFS= read -r wt; do
            rel=${wt#"$root"/}
            if [ -L "$wt/$name" ]; then
                printf '    %-28s symlink (shared? see gw-share)\n' "$rel"
            elif [ -e "$wt/$name" ]; then
                printf '    %-28s present\n' "$rel"
            else
                printf '    %-28s absent\n' "$rel"
            fi
        done < <(gw_worktrees)
    done
}

# Choose which worktree's copy to propagate: the requested branch, else the
# current worktree when it has one, else any worktree that does.
gw_copy_source() {
    local name="$1" want_from="$2" root here found
    root=$(gw_root)

    if [ -n "$want_from" ]; then
        if [ -e "$root/$want_from/$name" ]; then
            printf '%s\n' "$root/$want_from"
            return 0
        fi
        return 1
    fi

    here=$(git rev-parse --path-format=absolute --show-toplevel 2>/dev/null || true)
    if [ -n "$here" ] && [ -e "$here/$name" ]; then
        printf '%s\n' "$here"
        return 0
    fi

    found=$(gw_worktrees_with "$name")
    [ -n "$found" ] || return 1
    printf '%s\n' "${found%%$'\n'*}"
}

gw_copy_add_one() {
    local name="$1" want_from="$2" root src first
    root=$(gw_root)

    gw_assert_relpath "$name"
    case "$name" in
    "$gw_shared_dir" | "$gw_shared_dir"/*)
        gw_die "$name is inside the shared store"
        ;;
    esac

    if first=$(gw_donor_worktree ""); then
        gw_assert_not_tracked "$first" "$name"
    fi

    # Refuse to fight gw-share over the same path: one file cannot be both a
    # single shared file and a per-worktree copy.
    if git -C "$root" config --get-all --fixed-value "$gw_symlink_key" "$name" >/dev/null 2>&1; then
        gw_die "$name is already shared -- run 'gw-share rm $name' first"
    fi

    if gw_config_add "$root" "$gw_copy_key" "$name"; then
        gw_msg "$name: recorded in $gw_copy_key"
    else
        gw_msg "$name: already in $gw_copy_key"
    fi

    if src=$(gw_copy_source "$name" "$want_from"); then
        gw_propagate_copy "$name" "$src" "$root"
        gw_msg "  $gw_propagated copied, $gw_skipped already had it"
    else
        gw_msg "  does not exist in any worktree yet; create it and re-run 'gw-copy sync'"
    fi

    if first=$(gw_donor_worktree ""); then
        gw_warn_not_ignored "$first" "$name"
    fi
}

gw_copy_rm_one() {
    local name="$1" root
    root=$(gw_root)
    gw_assert_relpath "$name"

    if gw_config_remove "$root" "$gw_copy_key" "$name"; then
        gw_msg "$name: no longer copied into new worktrees (existing files kept)"
    else
        gw_msg "$name: was not configured"
    fi
}

gw_copy_sync() {
    local want_from="$1" root name src total=0
    root=$(gw_root)
    gw_resolve_lists "$root"

    if [ "${#gw_copy_files[@]}" -eq 0 ]; then
        gw_msg "no copied files configured"
        return 0
    fi

    for name in "${gw_copy_files[@]}"; do
        if src=$(gw_copy_source "$name" "$want_from"); then
            gw_msg "$name (from ${src#"$root"/}):"
            gw_propagate_copy "$name" "$src" "$root"
            gw_msg "  $gw_propagated copied, $gw_skipped already had it"
            total=$((total + gw_propagated))
        else
            gw_msg "$name: does not exist in any worktree yet"
        fi
    done
    gw_msg "$total file(s) copied"
}

case "${1-list}" in
list | "")
    gw_copy_list
    ;;
add)
    shift
    from=""
    paths=()
    while [ $# -gt 0 ]; do
        case "$1" in
        --from)
            [ $# -ge 2 ] || gw_die "--from needs a branch name"
            from="$2"
            shift 2
            ;;
        --from=*)
            from="${1#--from=}"
            shift
            ;;
        -*) gw_die "unknown option: $1" ;;
        *)
            paths+=("$1")
            shift
            ;;
        esac
    done
    [ "${#paths[@]}" -gt 0 ] || gw_die "nothing to copy -- pass at least one path"
    for p in "${paths[@]}"; do gw_copy_add_one "$p" "$from"; done
    ;;
rm | remove)
    shift
    [ $# -gt 0 ] || gw_die "nothing to remove -- pass at least one path"
    for p in "$@"; do gw_copy_rm_one "$p"; done
    ;;
sync)
    shift
    from=""
    while [ $# -gt 0 ]; do
        case "$1" in
        --from)
            [ $# -ge 2 ] || gw_die "--from needs a branch name"
            from="$2"
            shift 2
            ;;
        --from=*)
            from="${1#--from=}"
            shift
            ;;
        *) gw_die "unexpected argument: $1" ;;
        esac
    done
    gw_copy_sync "$from"
    ;;
-h | --help | help)
    gw_copy_usage
    ;;
*)
    gw_copy_usage
    gw_die "unknown subcommand: $1"
    ;;
esac
