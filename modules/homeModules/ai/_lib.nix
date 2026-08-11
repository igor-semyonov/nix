# Shared helpers for the AI TUI home modules (claude-code, antigravity).
# Underscore prefix keeps import-tree from importing this as a flake module;
# it is a plain function pulled in via `import ./_lib.nix { ... }`.
{
  pkgs,
  lib,
  self,
}: let
  aiDir = "${self}/modules/homeModules/ai";

  # Shared coding profile written to each TUI's global context file.
  contextText = ''
    I use Rust and Python for development, along with heavy usage of Nix.
    I also use LaTeX and conduct deep research into computational
    topics like cryptography and algorithms.
    Please be terse with comments, avoid pleasantries, and get straight to the point.
  '';

  # Statusline command shared by both TUIs. `name` disambiguates the two
  # binaries (claude-code-statusline vs antigravity-cli-statusline).
  mkStatusline = progName: let
    statuslineName = "${progName}-statusline";
    statusline = pkgs.writeShellApplication {
      name = statuslineName;
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
    inherit statuslineName statusline;
  };
in {
  inherit aiDir contextText mkStatusline;
}
