---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*)
description: Review a diff or branch for bugs, security, and style
argument-hint: [optional git ref to diff against, default HEAD]
---

## Context

- Diff: !`git diff ${ARGUMENTS:-HEAD}`

## Task

Review the diff as a senior engineer. Delegate deep analysis to the `code-reviewer` agent if the diff is large. Report grouped by severity (Correctness, Security, Style/Idiom, Simplification), each finding citing `file:line`. If clean, say so plainly.
