---
allowed-tools: Bash(nix flake check:*), Bash(nix build:*), Bash(nix eval:*), Bash(nix fmt:*)
description: Run nix flake check and triage any failures
---

## Task

Validate this flake and triage failures.

1. Run `nix flake check` (add `--no-build` first if a full build is too slow, then narrow down).
2. If it fails, read the evaluation/build error bottom-up and identify the root cause (type error, missing arg, bad hash, failing test).
3. Propose a concrete fix; apply it only if the user asked.
4. Report the final pass/fail state plainly.
