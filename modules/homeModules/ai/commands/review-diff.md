---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*)
description: Review the current working diff for bugs, style, and security issues
---

## Context

- Diff under review: !`git diff HEAD`

## Task

Review the diff above as a senior engineer. Report, grouped by severity:

- **Correctness / bugs** — logic errors, edge cases, race conditions.
- **Security** — injection, secret handling, unsafe input, permissions.
- **Style / idiom** — language conventions (Rust, Nix, Python), naming, dead code.
- **Simplification** — redundant or overly complex code.

Cite `file:line`. Be specific and terse. If the diff is clean, say so.
