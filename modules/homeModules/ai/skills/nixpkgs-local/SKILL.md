---
name: nixpkgs-local
description: Answer nixpkgs/NixOS/home-manager questions from the local clones at ~/src/github.com/nixos/nixpkgs/master and ~/src/github.com/nix-community/home-manager/master instead of a remote search service. Use when looking up a package version, attribute path, option declaration, module default, assertion, kernel/driver version table, or when checking what a nixpkgs or home-manager module actually sets. Also use before claiming an option is deprecated, renamed, or missing, and when a devShell or flake.lock needs a revision other than master checked out.
---

# Local nixpkgs and home-manager

Read these clones directly:

| repo         | path                                                          |
| ------------ | ------------------------------------------------------------- |
| nixpkgs      | `/home/igor/src/github.com/nixos/nixpkgs/master`              |
| home-manager | `/home/igor/src/github.com/nix-community/home-manager/master` |

**Read them directly.** There is deliberately no `mcp-nixos` or `context7` MCP
server — both forward the query to a third party. A clone is also _more_
correct: it is a real checkout at a known rev, whereas a search service returns
whatever it last indexed, which may not match the flake's pinned inputs.

home-manager matters as its own lookup because its modules are _not_ in
nixpkgs. `programs.*` / `services.*` options for a user environment, and their
assertions, live there — so "which home-manager option does X" and "what does
home-manager's firefox module actually assert" can only be answered from that
tree.

## If one is not there

These are `gw-*` worktree collections, not ordinary clones — see the
`git-worktree` skill. Clone to exactly those paths with:

```bash
dir=$(gw-clone https://github.com/nixos/nixpkgs master)
dir=$(gw-clone https://github.com/nix-community/home-manager master)
```

`gw-clone` derives `$GW_ROOT/<host>/<owner>/<repo>/<branch>` from the URL and
lowercases the owner, so with the default `GW_ROOT=~/src` these land on the
paths above. Each prints its checkout path on stdout. To add another branch
later: `gw-add <branch>`.

Check first rather than assuming — `gw-find nixpkgs` / `gw-find home-manager`
list every matching worktree, and other branches (`pr/<n>`, release branches)
may already exist. As of writing, nixpkgs is cloned (plus a `pr/552103`
worktree) and home-manager is not.

Both flake inputs track the default branch (no `ref` pinned in `flake.lock`),
so `master` is the branch to read for each.

## Reading a specific pin

When a devShell, a `flake.lock`, or a bisect needs a revision other than
`master`, check that revision out as its own worktree so the hash is visible in
the path:

```bash
cd /home/igor/src/github.com/nixos/nixpkgs/master
rev=$(jq -r '.nodes.nixpkgs.locked.rev' /path/to/flake.lock)
dir=$(gw-add "$rev" "$rev")       # -> ~/src/github.com/nixos/nixpkgs/<rev>
```

Same for home-manager, from any worktree of that collection:

```bash
cd /home/igor/src/github.com/nix-community/home-manager/master
rev=$(jq -r '.nodes."home-manager".locked.rev' /path/to/flake.lock)
dir=$(gw-add "$rev" "$rev")       # -> ~/src/.../home-manager/<rev>
```

**Pass the hash twice.** The second argument is the base. `gw-add <rev>` with
one argument finds no branch or remote branch by that name and therefore
creates a _new_ branch named `<rev>` based on `origin/<default>` — the right
path containing the wrong tree, with nothing to signal it. With the base given,
`gw-add` skips the remote fetch entirely (it treats that as an explicit "branch
from this revision") and does `git worktree add --no-track -b <rev> <path>
<rev>`.

A full 40-character SHA is a legal branch name, so the worktree lands at
`$GW_ROOT/<host>/<owner>/<repo>/<rev>`. Short hashes work too, but prefer the
full rev from `flake.lock` so the path is unambiguous and greppable.

If the revision has not been fetched, `gw-add` fails with
`base revision not found: <rev>` rather than guessing. Fetch it and retry:

```bash
git fetch origin "$rev"        # or: git fetch origin
```

These worktrees are pinned and have no upstream by design, so they will not
drift and `gw-prune` has no upstream-gone signal to act on. Remove them
deliberately with `gw-remove <rev>` when the pin stops mattering.

## Answering questions from them

Cheap orientation, in rough order of usefulness:

```bash
cd /home/igor/src/github.com/nixos/nixpkgs/master
git log -1 --format='%h %ad %s' --date=short     # what rev am I reading?

# Where a package or module lives
fd -t f 'package.nix' pkgs/by-name/fo/foo
rg -n 'allow-interfaces' nixos/modules/services/

# What a module actually sets (catches deprecations and surprise defaults)
rg -n -A8 'services\.avahi' nixos/modules/services/printing/ipp-usb.nix

# When something changed, and why
git log --oneline -S '<string>' -- <path>
git log -1 --format='%h %ad%n%n%B' --date=short <rev>
```

Same moves in home-manager, different layout — everything is under `modules/`,
with no `pkgs/` or `nixos/` split:

```bash
cd /home/igor/src/github.com/nix-community/home-manager/master
rg -n 'mkOption' modules/programs/firefox/        # option declarations
rg -n 'assertion' modules/programs/firefox/       # why an eval is failing
rg -l '<option-name>' modules/                    # which module owns an option
```

Three habits that matter:

- **Match the tree to the question.** `nixosConfigurations.<host>.config.*`
  questions are nixpkgs; `homeConfigurations."<user>@<host>".config.*` and
  anything under `home.*` / `programs.*` for a user are home-manager. An option
  missing from one is usually declared in the other.
- **The clone's `master` is not the flake's pinned rev.** For "what will my
  system actually do", evaluate the config instead:
  `nix eval '.#nixosConfigurations.<host>.config.<option>' --json`, or
  `nix eval '.#nixosConfigurations.<host>.pkgs.<attr>.version'`. Use the clone
  for _why_ and _where_; use `nix eval` for _what is in effect_.
- **`git log -S` on a file is the fastest way to date a regression.** When
  something broke after a `nix flake update`, find the commit that introduced
  the behaviour before theorising about it.

## Deprecated and renamed options

Do not guess. Renames and removals are declared in the module itself, usually
near the top:

```bash
rg -n 'mkRenamedOptionModule|mkRemovedOptionModule|mkAliasOptionModule' \
  nixos/modules/services/networking/avahi-daemon.nix
```

A renamed option still forwards its value but emits an eval warning; a removed
one does not. To see what a host is actually warning about:

```bash
nix eval '.#nixosConfigurations.<host>.config.warnings' --json
```

That is also the quickest way to confirm a fix landed, since it names the file
that defined the offending option.
