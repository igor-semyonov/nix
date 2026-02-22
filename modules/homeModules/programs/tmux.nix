{...}: {
  flake.homeModules.tmux = {pkgs, ...}: {
    # Tmux terminal multiplexer configuration
    programs.tmux = {
      enable = true;
      clock24 = true;

      baseIndex = 1;

      escapeTime = 300;
      historyLimit = 10000;
      keyMode = "vi";
      mouse = true;
      sensibleOnTop = true;
      terminal = "alacritty";

      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = dracula;
          extraConfig = ''
            set -g @dracula-show-powerline true
            set -g @dracula-show-flags true
            set -g @dracula-refresh-rate 20
            set -g @dracula-left-icon-padding 0
            set -g @dracula-plugins "cpu-usage gpu-usage ram-usage"
            set -g @dracula-border-contrast true
            set -g @dracula-show-empty-plugins false
            set -g @dracula-cpu-usage-colors "orange dark_gray"
            set -g @dracula-gpu-usage-colors "light_purple dark_gray"
            set -g @dracula-ram-usage-colors "orange dark_gray"
          '';
        }
        {
          plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
            pluginName = "vim-tmux-navigator";
            rtpFilePath = "vim-tmux-navigator.tmux";
            version = "unstable-2026-02-22";

            src = pkgs.fetchFromGitHub {
              owner = "igor-semyonov";
              repo = "vim-tmux-navigator";
              rev = "35e2efa3be600b7e210b57a147ef595292465dd2";
              hash = "sha256-uvKoW0P70rJQ3ak9RzmJNwH5xyes654Q1chdv4gDG8c=";
            };
          };
          extraConfig = ''
            bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
            bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
            bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
            bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
            # bind-key -n 'C-\\' if-shell "$is_vim" 'send-keys C-\\' 'select-pane -l'
          '';
        }
        # {
        #   plugin = vim-tmux-navigator;
        # }
        {
          plugin = sensible;
        }
      ];

      extraConfig = ''
        unbind C-s
        set -g prefix C-s

        set -g repeat-time 750
        set -g mouse on
        set -g extended-keys always
        set -g display-time 0
        set -g display-panes-time 5000
        set -g main-pane-width 50
        set -g status-position top
        set set-clipboard external

        unbind -T copy-mode-vi t
        bind-key -T copy-mode-vi   t  "send-keys -X copy-selection-no-clear \; run-shell \"tmux show-buffer | tts\" "

        unbind -T copy-mode-vi WheelUpPane
        unbind -T copy-mode-vi WheelDownPane
        bind -T copy-mode-vi WheelUpPane send -N1 -X scroll-up
        bind -T copy-mode-vi WheelDownPane send -N1 -X scroll-down

        unbind q
        bind q select-layout main-vertical

        bind-key -r C-n next-window
        bind-key -r C-p previous-window

        unbind z
        bind z display-panes

        unbind C-c
        bind C-v clock-mode

        unbind h
        unbind H
        bind h split-window -h
        bind H split-window -v

        unbind C-c
        bind C-c copy-mode

        unbind r
        bind r source-file ~/.config/tmux/tmux.conf

        unbind ^S
        bind -r s select-pane -Zt ":.{last}"
        bind ^S set -g status
        bind S choose-session

        bind t
        # unbind t
        bind t choose-tree

        unbind C-o
        bind -r C-o rotate-window

        unbind C-z
        bind -n C-z resize-pane -Z

        # List of plugins
        # set -g @plugin 'tmux-plugins/tpm'

        # Other examples:
        # set -g @plugin 'github_username/plugin_name'
        # set -g @plugin 'github_username/plugin_name#branch'
        # set -g @plugin 'git@github.com:user/plugin'
        # set -g @plugin 'git@bitbucket.com:user/plugin'

        # Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)

        # run '~/.config/tmux/plugins/tpm/tpm'
      '';
    };

    # Enable catppuccin theming for tmux.
  };
}
