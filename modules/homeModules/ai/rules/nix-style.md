---
description: Nix code style and conventions.
---

# Nix Style

- Format all Nix with the project's formatter (`nix fmt` / treefmt / alejandra); never hand-format.
- Prefer the module system and flakes. Split large configs into focused modules.
- Give every option a `type`, `default` (or make it required deliberately), and a `description`.
- Use `lib.mkIf`, `lib.mkMerge`, `lib.mkDefault`, and `lib.mkForce` intentionally; avoid `mkForce` unless overriding is truly needed.
- Pin inputs via the flake lock; never fetch from moving refs inside a derivation.
- Fixed-output derivations (`fetchFromGitHub`, `cargoHash`, `vendorHash`) must carry correct hashes — do not invent them; leave a placeholder and let the build report the real one.
- Prefer `pkgs.<name>` over channel-global references; keep `with pkgs; [ ... ]` scoped and short.
- Reference store paths for binaries (`${pkgs.foo}/bin/foo`) instead of relying on PATH.
