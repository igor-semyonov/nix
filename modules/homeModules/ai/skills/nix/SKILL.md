---
name: nix
description: A guide to managing Nix flakes, running reproducible environments, and updating flake inputs.
---

# Nix Mastery

## Flake Operations

To update all flake inputs:

```bash
nix flake update
```

To check flake metadata:

```bash
nix flake show
```

## Development Environments

To enter the development shell defined in `flake.nix`:

```bash
nix develop -c $SHELL
```
