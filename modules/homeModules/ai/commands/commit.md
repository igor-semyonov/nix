---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*)
description: Create a single atomic git commit for the current changes
---

## Context

- Status: !`git status`
- Diff (staged + unstaged): !`git diff HEAD`
- Recent commits (for style): !`git log --oneline -10`

## Task

Create one atomic commit for the changes above:

1. Stage the relevant files (respect what the user asked; otherwise stage all tracked changes).
2. Write a concise message matching the repository's existing style (imperative mood, no fluff).
3. Do not add co-author trailers unless the repo already uses them.
4. Show the resulting `git log --oneline -1`.
