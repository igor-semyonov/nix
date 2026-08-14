# shellcheck shell=bash
# gw-add <branch> [base] -- add a worktree, printing its path.

if [ $# -eq 0 ] || [ "$1" = -h ] || [ "$1" = --help ]; then
    cat >&2 <<'EOF'
usage: gw-add <branch> [base]

Add a worktree for <branch> at <collection-root>/<branch>.
  existing local branch   -> checked out
  remote-only branch      -> checked out tracking origin/<branch>
  new branch              -> created from [base] (default: origin's HEAD)
EOF
    [ $# -eq 0 ] && exit 1
    exit 0
fi

gw_add_worktree "$1" "${2:-}"
