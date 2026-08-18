{self, ...}: {
  flake.homeModules.zsh = {
    config,
    pkgs,
    ...
  }: {
    imports = [self.homeModules.git];

    home.sessionPath = [
      "$HOME/.local/bin"
    ];
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      initContent =
        /*
        bash
        */
        ''
          # shellcheck disable=all
          eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"

          ${config.igix.gitWorktree.shellIntegration}
        '';
      shellAliases = {
        ff = "fastfetch";
        ".." = "cd ..";
        ls = "eza --icons always"; # default view
        ll = "eza -bhlg --icons --group-directories-first"; # long list
        la = "eza -abhlg --icons --group-directories-first"; # all list
        lt = "eza --tree --level=2 --icons"; # tree

        gs = "git status";
        gd = "git diff";
        gcam = "git commit --all --message";
        gcm = "git commit --message";
        gcl = "git clone";
        gco = "git checkout";
        ggl = "git pull";
        ggp = "git push";
        ga = "git add";

        # Worktrees. The cd-ing verbs (gwa, gwr, gwc, gwcl, gwconvert,
        # gwpr) are shell functions from igix.gitWorktree.shellIntegration.
        gwl = "gw-list";
        gwp = "gw-prune";

        flatpak = "flatpak --user";
        lo = "libreoffice";

        xcp = "xclip -i -selection clipboard";

        j = "journal";

        nd = "nix develop";
      };
      # sessionVariables = {
      #   _ZO_DOCTOR = 0;
      # };
    };
  };
}
