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

            direnvAllow = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Run `direnv allow` in a new worktree that has an `.envrc`,
                whether git checked it out or it was seeded by `gw-share` /
                `gw-copy`. Each worktree is a distinct path, so direnv
                requires approval for each one.
              '';
            };

            direnvCache = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Copy an existing worktree's `.direnv` directory into a new
                worktree, so a fresh branch reuses the already-evaluated
                devShell instead of rebuilding it on first `cd`.

                nix-direnv keys its cache on a hash of the flake expression
                rather than the worktree path, so the cache is portable between
                worktrees of the same repo. The copy's timestamps are bumped
                past the freshly checked-out `flake.nix`/`flake.lock`, since
                nix-direnv invalidates on mtime.

                Skipped when `flake.nix` or `flake.lock` differ between the two
                worktrees -- the cache would be wrong for those inputs, and
                direnv would re-evaluate regardless.
              '';
            };

            shellIntegration = lib.mkOption {
              type = lib.types.lines;
              readOnly = true;
              default =
                if cfg.enable
                then gwScripts.shellIntegration
                else "";
              defaultText = lib.literalMD "the generated `gwa`/`gwc`/… shell functions";
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
            ];

            home = lib.mkIf cfg.enable {
              packages = [gwScripts];

              sessionVariables = {
                GW_ROOT = cfg.root;
                GW_DIRENV_ALLOW =
                  if cfg.direnvAllow
                  then "1"
                  else "0";
                GW_DIRENV_CACHE =
                  if cfg.direnvCache
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
