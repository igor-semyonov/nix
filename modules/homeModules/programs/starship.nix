{...}: {
  flake.homeModules.starship = {pkgs, ...}: let
    # The repo name, for the prompt's leading segment. `directory` alone cannot
    # provide this: with truncate_to_repo it prints the basename of the *worktree*
    # directory, which in a bare-repo + nested-worktree layout is the branch name
    # -- yielding "main main" and no clue which repo you are in.
    #
    # --git-common-dir points at the shared gitdir, so it resolves the same for
    # every worktree of a repo:
    #   <repo>/.git   normal clone            -> repo
    #   <repo>/.bare  worktree collection     -> repo
    #   <bare>.git    bare repo               -> bare
    # Prints nothing outside a working tree, which leaves the plain `directory`
    # output untouched for non-git directories and bare repos.
    repoName = pkgs.writeShellApplication {
      name = "starship-repo-name";
      runtimeInputs = [pkgs.git];
      text = ''
        common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
        [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] || exit 0

        base=''${common%/}
        base=''${base##*/}
        case $base in
        .git | .bare)
          parent=''${common%/*}
          parent=''${parent%/}
          printf '%s' "''${parent##*/}"
          ;;
        *) printf '%s' "''${base%.git}" ;;
        esac
      '';
    };
  in {
    # Starship configuration
    programs.starship = {
      enable = true;
      # enableZshIntegration = true;
      enableBashIntegration = true;
      settings = {
        add_newline = true;
        # Repo name first, then the path within the repo, then everything else in
        # its default order. `$all` skips modules already named in the format, so
        # `$directory` is not duplicated, and `${custom.repo}` would otherwise be
        # appended after the branch. Empty outside a git working tree.
        format = "\${custom.repo}$directory$all";
        directory = {
          style = "bold lavender";
          truncation_length = 3;
          truncation_symbol = "/…/";
          # Only set so `repo_root_format` takes effect; starship ignores that
          # format unless a repo-root style is configured.
          repo_root_style = "bold lavender";
          # Inside a repo, drop the root segment: ${custom.repo} already names
          # the repo, and at a worktree root $path is empty, so the redundant
          # "main main" collapses to just "id4-gremlin main".
          repo_root_format = "[$path]($style)[$read_only]($read_only_style) ";
        };
        aws = {
          disabled = true;
        };
        docker_context = {
          symbol = " ";
        };
        golang = {
          symbol = " ";
        };
        kubernetes = {
          disabled = false;
          style = "bold pink";
          symbol = "󱃾 ";
          format = "[$symbol$context( \($namespace\))]($style)";
          contexts = [
            {
              context_pattern = "arn:aws:eks:(?P<var_region>.*):(?P<var_account>[0-9]{12}):cluster/(?P<var_cluster>.*)";
              context_alias = "$var_cluster";
            }
          ];
        };
        helm = {
          symbol = " ";
        };
        gradle = {
          symbol = " ";
        };
        java = {
          symbol = " ";
        };
        kotlin = {
          symbol = " ";
        };
        lua = {
          symbol = " ";
        };
        package = {
          symbol = " ";
        };
        php = {
          symbol = " ";
        };
        # python = {
        #   symbol = " ";
        # };
        # rust = {
        #   symbol = " ";
        # };
        terraform = {
          symbol = " ";
        };
        custom.repo = {
          command = "${repoName}/bin/starship-repo-name";
          # The script decides for itself and prints nothing when not applicable,
          # so no separate `when` probe (and no extra subprocess) is needed.
          when = true;
          # --noprofile --norc: this is a fixed command, not user shell code.
          shell = ["${pkgs.bash}/bin/bash" "--noprofile" "--norc"];
          format = "[$output]($style)";
          style = "bold lavender";
        };
        right_format = "$kubernetes";
      };
    };
  };
}
