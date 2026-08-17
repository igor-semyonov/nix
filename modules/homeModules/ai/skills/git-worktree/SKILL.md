---
name: git-worktree
description: >-
  This machine manages git repos as bare-repo + nested-worktree collections
  driven by custom `gw-*` helper scripts, not as ordinary clones. Read this
  BEFORE running any git command that changes what is checked out, and before
  reasoning about repo layout or paths. TRIGGER whenever working in a local git
  repo and the task involves: switching/creating/deleting branches, `git
  checkout`/`switch`/`stash`, checking out a PR, cloning, cleaning up merged
  branches, "work on X while Y builds", locating a repo or branch on disk, or a
  path containing `.bare/`. Also trigger on the names gw-add, gw-clone,
  gw-convert, gw-find, gw-list, gw-pr, gw-prune, gw-remove, gwa, gwcd, gwcl,
  gwpr, gwr, gwconvert, GW_ROOT. SKIP for read-only work inside one already
  checked-out tree (log, diff, blame, grep, commit) that never changes branches.
---

# Git Worktrees (`gw-*` tooling)

Every repo is a **collection**: one bare object store plus one directory per
checked-out branch. There is no single "the repo directory" that switches
branches — branches are directories that coexist.

```
$GW_ROOT/<host>/<owner>/<repo>/     collection root
├── .bare/                          bare object store (the real gitdir)
├── .git                            gitfile: "gitdir: ./.bare"
├── main/                           worktree for branch main
├── feature-x/                      worktree for branch feature-x
└── pr/123/                         worktree for branch pr/123
```

`GW_ROOT` defaults to `~/src`. Nested branch names nest as directories
(`feat/auth` → `<root>/feat/auth/`).

**Prefer `gw-*` over raw `git worktree`/`git checkout`.** The helpers own the
layout, upstream tracking, untracked-file seeding, and direnv approval; raw
commands skip all of it.

## Two interfaces, and which one you can use

| Interface                | What it is                             | Usable from an agent shell |
| ------------------------ | -------------------------------------- | -------------------------- |
| `gw-add`, `gw-clone`, …  | packaged scripts on `PATH`             | **yes**                    |
| `gwa`, `gwcd`, `gwcl`, … | shell functions, interactive init only | no                         |

The `gw*` short forms exist only because a subprocess cannot change its parent's
directory — they wrap the script and `cd` to its output. They are defined in the
user's interactive shell init, so a non-interactive tool shell will not have
them. **Use the `gw-*` scripts; suggest the `gw*` functions to the user.**

Every script prints its destination path on **stdout** and all human-readable
output on **stderr**, so `dir=$(gw-add feature-x)` captures just the path.

## Recipes

```bash
# Start work on a branch: existing local -> checked out; remote-only -> checked
# out tracking origin/<branch>; neither -> created from origin's HEAD.
dir=$(gw-add feature-x)
dir=$(gw-add feature-x origin/release-2)   # explicit base for a new branch
git -C "$dir" status                       # then operate with -C, or cd "$dir"

# Review a GitHub PR (fetches pull/<n>/head into branch pr/<n>).
dir=$(gw-pr 123)

# Inspect the current collection: dirt marker, branch, upstream + ahead/behind.
gw-list

# Find worktrees across every collection under $GW_ROOT.
# Output: "<host>/<owner>/<repo> <branch>\t<abs-path>", optional substring filter.
gw-find nix-personal
gw-find                       # everything

# Clone a new repo as a collection (prints the default-branch checkout).
dir=$(gw-clone git@github.com:owner/repo.git)
dir=$(gw-clone https://github.com/owner/repo develop)   # specific branch

# Convert an ordinary clone, preserving branch and untracked files. By default it
# first MOVES the clone to where gw-clone would have put it (derived from origin).
dir=$(gw-convert)                    # or: gw-convert /path/to/clone
dir=$(gw-convert --no-move)          # convert in place, leave the clone where it is

# Tear down. Refuses on a dirty worktree unless forced; prints a safe landing dir.
gw-remove feature-x
gw-remove --force feature-x   # discard uncommitted changes
gw-remove                     # the worktree you are standing in

# Post-merge cleanup: fetch --prune, drop stale admin entries, then remove clean
# worktrees whose upstream is [gone] and delete their local branches.
gw-prune --dry-run            # always preview first
gw-prune --yes                # non-interactive; otherwise it prompts on /dev/tty
```

## Rules that matter

- **A branch lives in exactly one worktree.** Never `git checkout <other-branch>`
  to move around — `gw-add` it (already-checked-out branches return the existing
  path, so it is idempotent) and work there. This is the whole point of the
  layout: no stashing, no rebuilds lost to a branch switch.
- **Prefer parallel worktrees to stashing.** Long `cargo`/`nix build` in one, keep
  editing in another.
- **`gw-*` commands must run inside a collection.** They resolve the root by
  checking that `--git-common-dir` basename is `.bare`, and die with "not a
  worktree collection" otherwise. On a normal clone: `gw-convert` first.
  Exceptions: `gw-clone` and `gw-find` work from anywhere.
- **Don't `rm -rf` a worktree directory.** That strands an admin entry. Use
  `gw-remove` (which also `rmdir`s the empty parents nesting left behind) or
  `git worktree prune`.
- **`gw-convert` moves the repo by default.** It relocates the clone to
  `$GW_ROOT/<host>/<owner>/<repo>` (parsed from origin's URL) before converting,
  so the path you were in ceases to exist — the printed path is the new one.
  `--no-move` converts in place. Without an origin remote it refuses unless
  `--no-move` is given.
- **`gw-convert` refuses** on a repo that already has linked worktrees, has
  submodules, is already bare, is run from a linked worktree, or has detached
  HEAD. Fix the cause; do not work around it.
- Absolute paths are safest across worktrees. `git -C "$dir"` beats `cd`.

## New-worktree seeding

`gw-add`/`gw-pr`/`gw-clone` seed a fresh worktree from a sibling ("donor")
worktree and then approve direnv. Tracked files (`.envrc` and friends) are
already checked out by git and need no seeding. Existing files are never
overwritten.

| Env var            | Meaning                                                                             | Default           |
| ------------------ | ----------------------------------------------------------------------------------- | ----------------- |
| `GW_ROOT`          | base dir for collections                                                            | `~/src`           |
| `GW_SYMLINK_FILES` | `:`-separated untracked paths **symlinked** from the donor (shared, e.g. `.direnv`) | empty             |
| `GW_COPY_FILES`    | `:`-separated untracked paths **copied** from the donor (diverge per worktree)      | `.env:.env.local` |
| `GW_DIRENV_ALLOW`  | `1` to run `direnv allow` in a worktree with an `.envrc`                            | `1`               |

Symlinking a `.direnv` cache shares it across branches — and goes stale when
`flake.nix` differs between them. Copy, don't symlink, anything that should
diverge.

## Required git config

Set by the home-manager module; a collection misbehaves without it.

- `worktree.guessRemote = true` — otherwise `gw-add <remote-branch>` silently
  branches from HEAD instead of tracking `origin/<remote-branch>`.
- `worktree.useRelativePaths = true` — a collection survives being moved or
  renamed. Requires git ≥ 2.48 (implies `extensions.relativeWorktrees`).

## Source

Scripts, shell functions, and the home-manager options
(`igix.gitWorktree.{enable,root,symlinkFiles,copyFiles,direnvAllow}`) live in
`modules/homeModules/programs/git/` of the nix-personal flake. Shared helpers are
in `lib.sh`; each `gw-<verb>.sh` is concatenated onto it at build time. Build or
run standalone with `nix run .#git-worktree-scripts`. Every script also takes
`-h`/`--help`.
