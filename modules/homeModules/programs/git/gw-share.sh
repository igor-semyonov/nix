# shellcheck shell=bash
# gw-share -- manage untracked files shared across every worktree of a collection.
#
# One real file lives in <collection>/.gw-shared/ with a relative symlink in each
# worktree, so edits are shared and the file survives removing any worktree.
# The store sits beside .bare/, outside every worktree, so git never sees it --
# which is what makes it the right home for untracked secrets.

gw_share_usage() {
    cat >&2 <<'EOF'
usage: gw-share [list]
       gw-share add [--from <branch>] <path>...
       gw-share rm <path>...
       gw-share sync

Files shared across all worktrees, via <collection>/.gw-shared/.

  list   configured paths and their state in each worktree (default)
  add    adopt into the store, link into every worktree, record in git config
  rm     replace each link with a real file, then forget the path
  sync   link any worktree still missing a configured path

Paths are relative to the worktree root. --from picks which worktree's copy to
adopt when several differ.
EOF
}

# Print the store path, creating it on demand.
gw_share_store() {
    gw_shared_path "$(gw_root)"
}

gw_share_list() {
    local root shared name wt rel state
    root=$(gw_root)
    shared="$root/$gw_shared_dir"
    gw_resolve_lists "$root"

    if [ "${#gw_symlink_files[@]}" -eq 0 ]; then
        printf 'no shared files configured\n' >&2
        printf 'add one with: gw-share add <path>\n' >&2
        return 0
    fi

    for name in "${gw_symlink_files[@]}"; do
        if [ -e "$shared/$name" ]; then
            state="in $gw_shared_dir/"
        else
            state="MISSING from $gw_shared_dir/ -- create it in a worktree, then: gw-share sync"
        fi
        printf '%s  (%s)\n' "$name" "$state"

        while IFS= read -r wt; do
            rel=${wt#"$root"/}
            if [ -L "$wt/$name" ]; then
                if [ -e "$wt/$name" ]; then
                    printf '    %-28s linked\n' "$rel"
                else
                    printf '    %-28s BROKEN LINK\n' "$rel"
                fi
            elif [ -e "$wt/$name" ]; then
                printf '    %-28s regular file, not shared\n' "$rel"
            else
                printf '    %-28s absent\n' "$rel"
            fi
        done < <(gw_worktrees)
    done
}

# Adopt $1 into the store, then link it everywhere. $2 is an optional branch
# whose copy wins when several worktrees hold differing versions.
gw_share_add_one() {
    local name="$1" want_from="$2" root shared src candidates=() first from rel
    local differing=0 c
    root=$(gw_root)

    gw_assert_relpath "$name"
    case "$name" in
    "$gw_shared_dir" | "$gw_shared_dir"/*)
        gw_die "$name is inside the shared store itself"
        ;;
    esac

    shared=$(gw_share_store)
    src="$shared/$name"

    # A worktree is needed for the tracked/ignored checks; any one will do.
    if first=$(gw_donor_worktree ""); then
        gw_assert_not_tracked "$first" "$name"
    fi

    if [ -e "$src" ]; then
        gw_msg "$name: already in $gw_shared_dir/"
    else
        mapfile -t candidates < <(gw_worktrees_with "$name")

        if [ "${#candidates[@]}" -eq 0 ]; then
            gw_die "$name does not exist in any worktree -- create it first, then re-run"
        fi

        from="${candidates[0]}"
        if [ -n "$want_from" ]; then
            from="$root/$want_from"
            [ -e "$from/$name" ] ||
                gw_die "$name does not exist in $want_from"
        elif [ "${#candidates[@]}" -gt 1 ]; then
            # Adopting one copy deletes the others. Only proceed unasked when
            # every copy is byte-identical, so nothing can be lost silently.
            for c in "${candidates[@]:1}"; do
                cmp -s "${candidates[0]}/$name" "$c/$name" || differing=1
            done
            if [ "$differing" = 1 ]; then
                gw_msg "$name exists with differing content in:"
                for c in "${candidates[@]}"; do
                    gw_msg "    ${c#"$root"/}"
                done
                gw_die "pick one with: gw-share add --from <branch> $name"
            fi
        fi

        mkdir -p "$(dirname "$src")"
        mv -- "$from/$name" "$src"
        ln -srn "$src" "$from/$name"
        gw_msg "$name: adopted into $gw_shared_dir/ (from ${from#"$root"/})"

        # Identical duplicates elsewhere are now redundant; replace them with
        # links so every worktree reads the one real file.
        for c in "${candidates[@]}"; do
            [ "$c" != "$from" ] || continue
            [ ! -L "$c/$name" ] || continue
            rm -f -- "$c/$name"
        done
    fi

    if gw_config_add "$root" "$gw_symlink_key" "$name"; then
        gw_msg "  recorded in $gw_symlink_key"
    fi

    gw_propagate_symlink "$name" "$shared"
    gw_msg "  $gw_propagated linked, $gw_skipped already had it"

    if first=$(gw_donor_worktree ""); then
        gw_warn_not_ignored "$first" "$name"
    fi
}

# Stop sharing $1: give every worktree its own real copy, then drop the config.
gw_share_rm_one() {
    local name="$1" root shared wt rel restored=0
    root=$(gw_root)
    shared="$root/$gw_shared_dir"

    gw_assert_relpath "$name"

    if [ ! -e "$shared/$name" ]; then
        if gw_config_remove "$root" "$gw_symlink_key" "$name"; then
            gw_msg "$name: removed from $gw_symlink_key (was not in the store)"
        else
            gw_msg "$name: not shared"
        fi
        return 0
    fi

    # Replace links first, so no worktree is left pointing at a file we delete.
    while IFS= read -r wt; do
        rel=${wt#"$root"/}
        if [ -L "$wt/$name" ]; then
            rm -f -- "$wt/$name"
            cp -a "$shared/$name" "$wt/$name"
            gw_msg "  restored real file in $rel"
            restored=$((restored + 1))
        fi
    done < <(gw_worktrees)

    # ${var:?} so an empty variable aborts rather than expanding towards /.
    rm -rf -- "${shared:?}/${name:?}"
    gw_prune_parents "$shared/$name" "$shared"
    gw_config_remove "$root" "$gw_symlink_key" "$name" || true
    gw_msg "$name: no longer shared ($restored worktrees now hold their own copy)"
}

gw_share_sync() {
    local root shared name total=0
    root=$(gw_root)
    gw_resolve_lists "$root"

    if [ "${#gw_symlink_files[@]}" -eq 0 ]; then
        gw_msg "no shared files configured"
        return 0
    fi

    shared=$(gw_share_store)
    for name in "${gw_symlink_files[@]}"; do
        if [ ! -e "$shared/$name" ]; then
            # Configured but absent: adopt it now if some worktree grew one.
            if [ -n "$(gw_worktrees_with "$name")" ]; then
                gw_msg "$name: not in the store yet, adopting"
                gw_share_add_one "$name" ""
                # add already linked everything and reported its own counts.
                total=$((total + gw_propagated))
                continue
            fi
            gw_msg "$name: shared but does not exist anywhere yet"
            continue
        fi
        gw_msg "$name:"
        gw_propagate_symlink "$name" "$shared"
        gw_msg "  $gw_propagated linked, $gw_skipped already had it"
        total=$((total + gw_propagated))
    done
    gw_msg "$total link(s) created in total"
}

case "${1-list}" in
list | "")
    gw_share_list
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
    [ "${#paths[@]}" -gt 0 ] || gw_die "nothing to share -- pass at least one path"
    for p in "${paths[@]}"; do gw_share_add_one "$p" "$from"; done
    ;;
rm | remove | unshare)
    shift
    [ $# -gt 0 ] || gw_die "nothing to unshare -- pass at least one path"
    for p in "$@"; do gw_share_rm_one "$p"; done
    ;;
sync)
    gw_share_sync
    ;;
-h | --help | help)
    gw_share_usage
    ;;
*)
    gw_share_usage
    gw_die "unknown subcommand: $1"
    ;;
esac
