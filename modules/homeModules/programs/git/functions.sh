# shellcheck shell=bash
# Interactive wrappers around the gw-* scripts. These must be shell functions
# rather than packaged scripts: a subprocess cannot change the parent's cwd.
# Each helper prints its destination on stdout and diagnostics on stderr.

gwcl() {
    local dest
    dest=$(@gwClone@ "$@") || return
    [ -n "$dest" ] && cd "$dest" || return
}

gwconvert() {
    local dest
    dest=$(@gwConvert@ "$@") || return
    [ -n "$dest" ] && cd "$dest" || return
}

# Add (or jump to) a worktree for a branch.
gwa() {
    local dest
    dest=$(@gwAdd@ "$@") || return
    [ -n "$dest" ] && cd "$dest" || return
}

# Remove a worktree, landing in a sibling worktree or the collection root, so
# the shell never ends up sitting in a deleted directory.
gwr() {
    local dest
    dest=$(@gwRemove@ "$@") || return
    [ -n "$dest" ] && cd "$dest" || return
}

# Check a GitHub PR out into its own worktree.
gwpr() {
    local dest
    dest=$(@gwPr@ "$@") || return
    [ -n "$dest" ] && cd "$dest" || return
}

# Fuzzy-jump to any worktree under $GW_ROOT. With one match, jumps directly.
gwc() {
    local lines count dest
    lines=$(@gwFind@ "$@") || return
    if [ -z "$lines" ]; then
        printf 'no worktrees match\n' >&2
        return 1
    fi

    count=$(printf '%s\n' "$lines" | wc -l)
    if [ "$count" -eq 1 ]; then
        dest=${lines##*$'\t'}
    else
        # --no-multi last-wins over a --multi in the user's FZF_DEFAULT_OPTS, and
        # neutralises a select-all binding: with multi-select fzf returns one line
        # per marked row, and `cd` would get a mangled multi-line argument.
        dest=$(printf '%s\n' "$lines" |
            @fzf@ --with-nth=1,2 --delimiter='\t' --prompt='worktree > ' \
                --preview='@git@ -C {2} log --oneline --decorate --color=always -15' \
                --preview-window='right:55%:wrap' --no-multi) || return
        # Belt and braces: keep the first line only, then the field after the
        # last tab, so a stray multi-selection still yields one usable path.
        dest=${dest%%$'\n'*}
        dest=${dest##*$'\t'}
    fi

    [ -n "$dest" ] && cd "$dest" || return
}
