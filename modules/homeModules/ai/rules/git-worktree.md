---
description: Local git repos on this machine are bare + nested-worktree collections.
---

# Git Worktrees

Repos here are not ordinary clones: each is a `.bare/` object store with one
directory per checked-out branch, managed by the `gw-*` scripts.

- Before any git operation that changes what is checked out — branch
  create/switch/delete, `checkout`/`switch`/`stash`, PR checkout, clone, merged-branch
  cleanup — or before reasoning about repo layout and paths, invoke the
  `git-worktree` skill.
- Never `git checkout <other-branch>` to move between branches; `gw-add <branch>`
  and work in the directory it prints.
