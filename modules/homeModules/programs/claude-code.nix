{...}: {
  flake.homeModules.claude-code = {pkgs, ...}: let
    claude-statusline = pkgs.writeShellApplication {
      name = "claude-statusline";
      runtimeInputs = with pkgs; [jq git];
      text = ''
        input=$(cat)

        model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
        branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "No Git")
        context_total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens')
        context_total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens')
        context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size')
        context_current_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens')
        context_current_output=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens')
        context_current_cache_creation_input=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens')
        context_current_cache_read_input=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens')
        remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // 100')

        if [ "$remaining_pct" -lt 15 ]; then
            color=$'\033[0;31m' # Red
        elif [ "$remaining_pct" -lt 40 ]; then
            color=$'\033[0;33m' # Yellow
        else
            color=$'\033[0;32m' # Green
        fi

        reset=$'\033[0m'

        printf "🤖 %s|🌿 %s|🧠 %s%s%% of %.0e%s %.1e:%.1e %.1e:%.1e %.1e:%.1e" \
            "$model" \
            "$branch" \
            "$color" \
            "$remaining_pct" \
            "$context_window_size" \
            "$reset" \
            "$context_total_input" \
            "$context_total_output" \
            "$context_current_input" \
            "$context_current_output" \
            "$context_current_cache_creation_input" \
            "$context_current_cache_read_input" \
          | sed -e "s/e+0/e/g"
      '';
    };
  in {
    home.packages = [claude-statusline];
    programs.claude-code = {
      enable = true;
      settings = {
        statusLine = {
          type = "command";
          command = "claude-statusline";
        };
      };
    };
  };
}
