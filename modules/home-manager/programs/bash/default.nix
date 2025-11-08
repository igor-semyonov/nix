{pkgs, ...}: {
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
        SSH_ENV="$HOME/.ssh/agent-environment"
        function start_agent {
            echo "Initialising new SSH agent..."
            /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "''${SSH_ENV}"
            echo succeeded
            chmod 600 "''${SSH_ENV}"
            . "''${SSH_ENV}" > /dev/null
            /usr/bin/ssh-add;
        }
        # Source SSH settings, if applicable
        if [ -f "''${SSH_ENV}" ]; then
            . "''${SSH_ENV}" > /dev/null
            #ps ''${SSH_AGENT_PID} doesn't work under cywgin
            ps -ef | grep ''${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
                start_agent;
            }
        else
            start_agent;
        fi

        eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
      '';
    shellAliases = {
      ".." = "cd ..";
      ls = "eza --icons always"; # default view
      ll = "eza -bhl --icons --group-directories-first"; # long list
      la = "eza -abhl --icons --group-directories-first"; # all list
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
      lo = "flatpak run org.libreoffice.LibreOffice";

      xcp = "xclip -i -selection clipboard";

      j = "journal";
    };
    sessionVariables = {
      _ZO_DOCTOR = 0;
    };
  };
}
