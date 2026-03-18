{...}: {
  flake.homeModules.bash = {pkgs, ...}: {
    # Install bat via home-manager module
    programs.bash = {
      enable = true;
      enableCompletion = true;
      historyControl = ["erasedups" "ignoreboth"];
      initExtra =
        /*
        bash
        */
        ''
          # shellcheck disable=all
          SSH_ENV="$HOME/.ssh/agent-environment"
          function start_agent {
              echo "Initialising new SSH agent..."
              # shellcheck disable=SC1054,1083,1009
              ${pkgs.openssh}/bin/ssh-agent | sed 's/^echo/#echo/' > "''${SSH_ENV}"
              chmod 600 "''${SSH_ENV}"
              # shellcheck disable=SC1073
              source "''${SSH_ENV}" > /dev/null
              ${pkgs.openssh}/bin/ssh-add;
              echo Succeeded!
          }
          # Source SSH settings, if applicable
          if [ -f "''${SSH_ENV}" ]; then
              . "''${SSH_ENV}" > /dev/null
              ps -ef | grep ''${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
                  start_agent;
              }
          else
              start_agent;
          fi

          eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
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

        flatpak = "flatpak --user";
        lo = "libreoffice";

        xcp = "xclip -i -selection clipboard";

        j = "journal";

        nd = "nix develop";
      };
      sessionVariables = {
        _ZO_DOCTOR = 0;
        LIBVIRT_DEFAULT_URI = "qemu:///system";
      };
    };
  };
}
