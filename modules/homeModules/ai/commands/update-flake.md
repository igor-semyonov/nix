---
allowed-tools: Bash(nix flake update:*), Bash(nix flake lock:*), Bash(git diff:*), Bash(git add:*)
description: Update Nix flake inputs and summarize what changed
---

## Task

Update this project's Nix flake inputs and report the result.

1. Run `nix flake update` (or `nix flake lock --update-input <input>` if the user named a specific input in $ARGUMENTS).
2. Show the diff of `flake.lock`.
3. Summarize which inputs moved and to what (old rev -> new rev), flagging any major version jumps.
4. Do NOT commit unless the user asks.
