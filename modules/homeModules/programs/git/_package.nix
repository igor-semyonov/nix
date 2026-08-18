# Package definition for the gw-* worktree scripts.
# Underscore prefix keeps import-tree from importing this as a flake module;
# it is a plain callPackage-style function, instantiated in ../git.nix.
{
  lib,
  coreutils,
  direnv,
  fd,
  findutils,
  fzf,
  gawk,
  git,
  symlinkJoin,
  writeShellApplication,
}: let
  # Each script is lib.sh plus its own body, so the helpers live in one place and
  # shellcheck/shfmt see ordinary shell files on disk. Configuration is read from
  # the environment (GW_ROOT and friends) rather than baked in, which keeps these
  # pure packages usable outside home-manager.
  mkScript = name: file:
    writeShellApplication {
      inherit name;
      runtimeInputs = [
        coreutils
        direnv
        fd
        findutils
        gawk
        git
      ];
      bashOptions = ["errexit" "nounset" "pipefail"];
      text = ''
        ${builtins.readFile ./lib.sh}
        ${builtins.readFile file}
      '';
    };

  scripts = lib.mapAttrs mkScript {
    gw-add = ./gw-add.sh;
    gw-clone = ./gw-clone.sh;
    gw-convert = ./gw-convert.sh;
    gw-copy = ./gw-copy.sh;
    gw-find = ./gw-find.sh;
    gw-list = ./gw-list.sh;
    gw-pr = ./gw-pr.sh;
    gw-prune = ./gw-prune.sh;
    gw-remove = ./gw-remove.sh;
    gw-share = ./gw-share.sh;
  };

  # Shell function definitions for the verbs that must change the caller's
  # directory -- a subprocess cannot do that, so these are sourced, not packaged.
  # Store paths are substituted in so the functions never depend on PATH.
  shellIntegration =
    builtins.replaceStrings
    [
      "@gwAdd@"
      "@gwClone@"
      "@gwConvert@"
      "@gwFind@"
      "@gwPr@"
      "@gwRemove@"
      "@fzf@"
      "@git@"
    ]
    [
      (lib.getExe scripts.gw-add)
      (lib.getExe scripts.gw-clone)
      (lib.getExe scripts.gw-convert)
      (lib.getExe scripts.gw-find)
      (lib.getExe scripts.gw-pr)
      (lib.getExe scripts.gw-remove)
      (lib.getExe fzf)
      (lib.getExe git)
    ]
    (builtins.readFile ./functions.sh);
in
  symlinkJoin {
    name = "git-worktree-scripts";
    paths = lib.attrValues scripts;

    # `scripts` so `nix build .#git-worktree.gw-add` can test one in isolation;
    # `shellIntegration` for bash/zsh init to source.
    passthru = scripts // {inherit shellIntegration;};

    meta = {
      description = "Helper scripts for a bare-repo + nested-worktree git workflow";
      longDescription = ''
        Manages git repositories as collections of worktrees: a bare object store
        in .bare/ with a .git gitfile beside it, and each branch checked out into
        a nested directory named after the branch.

        Reads configuration from the environment: GW_ROOT (base directory for
        collections), GW_DIRENV_ALLOW and GW_DIRENV_CACHE.

        Which untracked files a new worktree inherits is per-collection state
        rather than a global preference, so it lives in each collection's own
        git config (gw.symlink / gw.copy) and is managed with `gw-share` and
        `gw-copy`. Shared files are stored once per collection in .gw-shared/
        and symlinked into every worktree, which is where untracked secrets
        belong; copied files diverge per worktree.
      '';
      platforms = lib.platforms.unix;
      mainProgram = "gw-list";
    };
  }
