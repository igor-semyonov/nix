---
name: nix
description: Manage Nix flakes, dev shells, and reproducible builds. Use when working with flake.nix, building derivations, or entering dev environments.
---

# Nix

## Flake operations

```bash
nix flake show            # outputs of this flake
nix flake metadata        # inputs and lock info
nix flake update          # update all inputs
nix flake lock --update-input <name>   # update one input
nix flake check           # evaluate + run checks
```

## Building & running

```bash
nix build .#<attr>        # build an output -> ./result
nix run .#<attr>          # build and run
nix eval .#<attr>         # evaluate an expression
nix eval --raw .#<attr>   # raw string output
```

Add `--show-trace` for full traces and `-L` to stream build logs.

## Dev shells

```bash
nix develop               # enter the default devShell
nix develop -c $SHELL     # enter it using your shell
nix develop .#<name>      # a named devShell
```

## Inspecting interactively

```bash
nix repl
:lf .                     # load the current flake
```

## Debugging eval errors

- Read the trace **bottom-up**.
- `infinite recursion` → a value references itself; often needs `lib.mkIf` or breaking a cycle.
- `attribute 'X' missing` → a module arg or option isn't provided.
- Use the `nixos` MCP server to look up option/package details.
