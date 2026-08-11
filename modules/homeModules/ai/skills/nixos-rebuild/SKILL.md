---
name: nixos-rebuild
description: Build, switch, and debug NixOS and home-manager generations, including flake-based configs. Use when applying or troubleshooting NixOS/home-manager changes.
---

# NixOS / home-manager rebuilds

## NixOS (flake)

```bash
sudo nixos-rebuild switch --flake .#<host>     # build + activate + set as boot default
sudo nixos-rebuild test --flake .#<host>       # activate without touching bootloader
sudo nixos-rebuild build --flake .#<host>      # build only, no activation
sudo nixos-rebuild boot --flake .#<host>       # activate on next boot
```

Add `--show-trace` for full evaluation traces and `-L` to stream build logs.

## home-manager (flake)

```bash
home-manager switch --flake .#<user>@<host>
# or build the activation package directly:
nix build .#homeConfigurations.'<user>@<host>'.activationPackage
```

## Inspecting before switching

```bash
nix flake check                      # evaluate + run checks
nixos-rebuild build --flake .#<host> && nvd diff /run/current-system ./result
```

`nvd diff` shows exactly which packages change between generations.

## Rollback

```bash
sudo nixos-rebuild switch --rollback
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

## Debugging eval errors

- Read the trace **bottom-up**; the root cause is usually near the bottom.
- `infinite recursion` → a config value references itself (often via `config.` without `lib.mkIf`).
- `attribute 'X' missing` → a module expects an arg or option not provided.
- Use `nix repl` with `:lf .` to load the flake and inspect attributes interactively.
