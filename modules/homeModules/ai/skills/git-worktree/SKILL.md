---
name: git-worktree
description: Use git worktrees to work on multiple branches simultaneously without stashing or re-cloning. Use when juggling parallel branches, reviews, or long builds.
---

# Git Worktrees

Worktrees check out multiple branches of one repo into separate directories that share the same `.git` object store.

## Create

```bash
git worktree add ../feature-x feature-x     # existing branch
git worktree add -b hotfix ../hotfix main    # new branch 'hotfix' from main
```

## List / inspect

```bash
git worktree list
```

## Remove

```bash
git worktree remove ../feature-x
git worktree prune                 # clean up stale administrative entries
```

## Why

- Review a PR branch while your main work keeps building in another worktree.
- Run a long `cargo build` / `nix build` in one worktree, keep editing in another.
- No stashing, no re-cloning; branches share objects so it's cheap.

## Gotchas

- A branch can be checked out in only one worktree at a time.
- Deleting the directory manually leaves a stale entry — use `git worktree remove` or `git worktree prune`.
