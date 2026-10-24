---
description: Nix code style and conventions, and where nixpkgs and home-manager are checked out locally.
---

# Local nixpkgs and home-manager

- nixpkgs: `/home/igor/src/github.com/nixos/nixpkgs/master`
- home-manager: `/home/igor/src/github.com/nix-community/home-manager/master`

Read these instead of reaching for a remote search service — there is
deliberately no `mcp-nixos`/`context7` MCP, and a clone reflects a known rev.
home-manager's modules are not in nixpkgs, so `programs.*`/`home.*` options and
assertions can only be found in its own tree. Before looking up an attribute
path, option declaration, module default, or whether an option is deprecated,
invoke the `nixpkgs-local` skill. Use `nix eval` on the host's config for what
is actually _in effect_.

# Nix Style

- Format all Nix with the project's formatter (`nix fmt` / treefmt / alejandra); never hand-format.
- Prefer the module system and flakes. Split large configs into focused modules.
- Give every option a `type`, `default` (or make it required deliberately), and a `description`.
- Use `lib.mkIf`, `lib.mkMerge`, `lib.mkDefault`, and `lib.mkForce` intentionally; avoid `mkForce` unless overriding is truly needed.
- Pin inputs via the flake lock; never fetch from moving refs inside a derivation.
- Fixed-output derivations (`fetchFromGitHub`, `cargoHash`, `vendorHash`) must carry correct hashes — do not invent them; leave a placeholder and let the build report the real one.
- Prefer `pkgs.<name>` over channel-global references; keep `with pkgs; [ ... ]` scoped and short.
- Reference store paths for binaries (`${pkgs.foo}/bin/foo`) instead of relying on PATH.
