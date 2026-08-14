# Repo layout

flake-parts + `import-tree`. `flake.nix` is only inputs plus
`inputs.import-tree ./modules` — every `.nix` under `modules/` is auto-imported
as a flake-parts module. Adding a file registers it; there is no import list to
update. `modules/systems.nix` sets the system list.

Modules do not define config directly. They publish
`flake.nixosModules.<name>` / `flake.homeModules.<name>`, which other modules
consume via `self.nixosModules` / `self.homeModules`.

```
modules/
  hosts/            one file per host, or a dir (billy/{config,disk}.nix)
  nixosModules/     flake.nixosModules.*  (programs/, services/ subdirs)
  homeModules/      flake.homeModules.*   (programs/, ai/, hyprland/ subdirs)
  users.nix         central user definitions
  igix.nix          desktop profile bundles
  secrets.nix       sops-nix wiring
  overlays.nix      `stable-pkgs` exposes nixpkgs-stable as `pkgs.stable`
  formatter.nix     treefmt (alejandra, prettier, stylua, taplo, yamlfmt, shfmt)
```

## Hosts

A host file builds a `let` block of `hostname`, `system`, `includedUsers`,
`nixosModules`, `homeModules`, `hardware-configuration`, then calls
`buildNixosAndHomeManager` and ends with `in {inherit (result) flake perSystem;}`.

`buildNixosAndHomeManager` comes from `_module.args` in `modules/hosts/builder.nix`,
which produces `flake.nixosConfigurations.<hostname>`, a
`perSystem.packages.<hostname>-vm` build (extended with `nixosVmModules`), and
`flake.homeConfigurations."<user>@<hostname>"`.

Host-specific inline config goes in an anonymous module inside the host's
`nixosModules` list. Anything reusable belongs in `modules/nixosModules/`.

## Users

Defined once in `modules/users.nix` as `users.<name> = pkgs: hostname: { nixos, home }`
— a function of pkgs and hostname, so per-host email/git-key/stateVersion are
selected by attrset lookup on `hostname`. Hosts opt in via `includedUsers`.
`filterUsers` and `usersToNixos` are `_module.args` helpers.
`homeModules.users` declares the `userConfig` option (name, fullName, email, gitKey).

## Conventions

Custom options live under the `igix.*` namespace (`igix.btrbk`, `igix.nas`,
`igix.ai`, `igix.virtualisation`, `igix.nvim`, `igix.flatpak`, `igix.mcp`).
Reusable modules should gate themselves behind `igix.<name>.enable` rather than
enabling unconditionally.

Aggregates: `nixosModules.common` → `common-headless` / `common-desktop`;
`igix.nix` bundles `igix-desktop`, `igix-desktop-linux`, `igix-desktop-mac`.

Secrets are sops-nix, keyed to each host's SSH host key, with the encrypted
material in the external `sops-secrets` input (`flake = false`).

## Commands

Recipes are in `.justfile` (dotfile) at the repo root: `just switch`, `just boot`,
`just build <host>`, `just home`. Remote hosts build locally and push the
closure — `just billy` (switch), `just billy-test` (test, use for anything that
can break connectivity), `just billy-build`. Format with `nix fmt`.

# Conventions

## Sizes

Write disk/partition sizes as explicit KiB: `"2048K"`, `"${toString (1024 * 1024)}K"`.
Never `2M`/`1G` — the binary intent must be visible in the source.

## Comments

Terse. Comment only non-obvious technical reasoning — why Vultr's IPv6 needs RA
instead of a static gateway, why an option is overridden elsewhere at install
time. Never restate what the code already says, and never annotate an obvious
consequence of the host's specs.
