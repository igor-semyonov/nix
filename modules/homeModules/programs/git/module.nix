{self, ...}: {
  # Worktree helper scripts as a flake output, so they can be built and run
  # standalone (`nix run .#git-worktree-scripts -- ...`) as well as installed.
  perSystem = {pkgs, ...}: {
    packages.git-worktree-scripts = pkgs.callPackage ./_package.nix {};
  };

  # `key` deduplicates this module when several importers pull it in -- bash and
  # zsh both do, for the worktree shell integration. Without it the module system
  # treats each import as a fresh declaration of igix.gitWorktree.* and fails.
  flake.homeModules.git = {
    key = "igix/homeModules/git";
    imports = [
      (
        {
          config,
          lib,
          pkgs,
          ...
        }: let
          cfg = config.igix.gitWorktree;
          gwScripts = self.packages.${pkgs.stdenv.hostPlatform.system}.git-worktree-scripts;
        in {
          options.igix.gitWorktree = {
            enable =
              lib.mkEnableOption "git worktree helper scripts"
              // {
                default = true;
              };

            root = lib.mkOption {
              type = lib.types.singleLineStr;
              default = "${config.home.homeDirectory}/src";
              defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/src"'';
              description = ''
                Base directory holding worktree collections. `gw-clone` places a
                repo at `<root>/<host>/<owner>/<repo>/`, with each branch checked
                out into a nested subdirectory. Exported as `GW_ROOT`.
              '';
            };

            symlinkFiles = lib.mkOption {
              type = lib.types.listOf lib.types.singleLineStr;
              default = [];
              example = [
                ".direnv"
                ".tool-versions"
              ];
              description = ''
                Untracked files shared across every worktree in a collection.
                The real file lives in `<collection>/.gw-shared/`, beside
                `.bare/`, with a relative symlink in each worktree, so edits are
                shared and the file survives removing any worktree. A file that
                already exists in a worktree is moved into the store the first
                time it is shared. Paths are relative to the worktree root;
                missing files are skipped. Must not contain `:`.

                This is where untracked secrets belong: the store is outside
                every worktree, so git never sees it, and it is created `0700`
                with file modes preserved.

                Empty by default: a tracked file (`.envrc` and friends) is
                already checked out into every worktree by git, and existing
                files are never overwritten. Use this for deliberately
                gitignored state, such as sharing a `.direnv` cache -- at the
                cost of staleness when `flake.nix` differs between branches.

                Per-repository overrides live in the collection's own git
                config and replace this list:
                `git config --add gw.symlink .secrets`.
              '';
            };

            copyFiles = lib.mkOption {
              type = lib.types.listOf lib.types.singleLineStr;
              default = [".env" ".env.local"];
              example = [
                ".env"
                "config.local.toml"
              ];
              description = ''
                Untracked files copied into a new worktree from an existing one,
                for content that should diverge per worktree. Paths are relative
                to the worktree root; missing files are skipped. Must not
                contain `:`.

                Per-repository overrides live in the collection's own git
                config and replace this list: `git config --add gw.copy .env`.
                `git config gw.inherit false` disables seeding entirely for one
                collection.
              '';
            };

            direnvAllow = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Run `direnv allow` in a new worktree that has an `.envrc`,
                whether git checked it out or it came from
                {option}`igix.gitWorktree.symlinkFiles`. Each worktree is a
                distinct path, so direnv requires approval for each one.
              '';
            };

            shellIntegration = lib.mkOption {
              type = lib.types.lines;
              readOnly = true;
              default =
                if cfg.enable
                then gwScripts.shellIntegration
                else "";
              defaultText = lib.literalMD "the generated `gwa`/`gwcd`/… shell functions";
              description = ''
                Shell function definitions for the verbs that must change the
                calling shell's directory. Source from bash's `initExtra` or
                zsh's `initContent`. Read-only; set the other options to
                influence behaviour.
              '';
            };
          };

          config = {
            programs = {
              git = {
                enable = true;
                settings = {
                  user = {
                    name = config.userConfig.fullName;
                    email = config.userConfig.email;
                  };
                  pull.rebase = "true";
                  worktree = lib.mkIf cfg.enable {
                    # Without this, `gw-add <remote-branch>` silently branches
                    # from HEAD instead of tracking origin/<remote-branch>.
                    guessRemote = true;
                    # Keeps a collection working after it is moved or renamed.
                    # Implies extensions.relativeWorktrees, which git older
                    # than 2.48 cannot read.
                    useRelativePaths = true;
                  };
                };
                signing = {
                  key = config.userConfig.gitKey;
                  signByDefault = true;
                };
                lfs.enable = true;
              };
              delta = {
                enable = true;
                enableGitIntegration = true;
                options = {
                  keep-plus-minus-markers = true;
                  light = false;
                  line-numbers = true;
                  navigate = true;
                  width = 70;
                };
              };
            };

            assertions = [
              {
                assertion = !cfg.enable || cfg.root != "";
                message = "igix.gitWorktree.root must not be empty.";
              }
              {
                # The scripts receive these as colon-separated lists.
                assertion = !lib.any (lib.hasInfix ":") (cfg.symlinkFiles ++ cfg.copyFiles);
                message = "igix.gitWorktree.symlinkFiles/copyFiles entries must not contain ':'.";
              }
            ];

            home = lib.mkIf cfg.enable {
              packages = [gwScripts];

              sessionVariables = {
                GW_ROOT = cfg.root;
                GW_SYMLINK_FILES = lib.concatStringsSep ":" cfg.symlinkFiles;
                GW_COPY_FILES = lib.concatStringsSep ":" cfg.copyFiles;
                GW_DIRENV_ALLOW =
                  if cfg.direnvAllow
                  then "1"
                  else "0";
              };
            };
          };
        }
      )
    ];
  };
}
