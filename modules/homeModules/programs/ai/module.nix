{self, ...}: let
  commonConfig = {
    pkgs,
    lib,
    isAntigravity,
  }: let
    progName =
      if isAntigravity
      then "antigravity-cli"
      else "claude-code";
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
  in
    {
      home.packages = [statusline];
      programs."${progName}" =
        {
          enable = true;
          context = ''
            I use Rust and Python for development, along with heavy usage of Nix.
            I also occasionally use LaTeX and conduct deep research into computational topics like cryptography and algorithms.
            Please be terse with comments, avoid pleasantries, and get straight to the point.
          '';
          settings = {
            mouse = false;
            statusLine = {
              type = "command";
              command = statuslineName;
            };
          };
          enableMcpIntegration = true;
          skills = let
            skillsDir = "${self}/modules/homeModules/programs/ai/skills";
            dirs = builtins.attrNames (lib.filterAttrs (n: v: v == "directory") (builtins.readDir skillsDir));
          in builtins.listToAttrs (map (name: {
            inherit name;
            value = "${self}/modules/homeModules/programs/ai/skills/${name}";
          }) dirs);
        }
        // lib.optionalAttrs (!isAntigravity) {
          outputStyles = {
            concise = ''
              Provide extremely concise, direct answers. Focus strictly on code and solutions.
            '';
            detailed = ''
              Provide comprehensive explanations of underlying concepts, especially for cryptography, algorithms, and Nix.
            '';
          };
          plugins = [
            "deep-research"
            "system-analyzer"
            "code-reviewer"
          ];
          marketplaces = [
            "https://marketplace.example.com"
          ];
          agentsDir = "${self}/modules/homeModules/programs/ai/agents";
          commandsDir = "${self}/modules/homeModules/programs/ai/commands";
          hooksDir = "${self}/modules/homeModules/programs/ai/hooks";
          rulesDir = "${self}/modules/homeModules/programs/ai/rules";
        };
    }
    // (lib.optionalAttrs isAntigravity {
      home.file = {
        ".gemini/config/agents".source = "${self}/modules/homeModules/programs/ai/agents";
        ".gemini/config/commands".source = "${self}/modules/homeModules/programs/ai/commands";
        ".gemini/config/hooks".source = "${self}/modules/homeModules/programs/ai/hooks";
        ".gemini/config/rules".source = "${self}/modules/homeModules/programs/ai/rules";
      };
    });
in {
  flake.homeModules = {
    mcp-servers = {
      pkgs,
      lib,
      config,
      ...
    }: {
      options.igix.mcp.gh = {
        url = lib.mkOption {
          type = lib.types.str;
          default = "https://api.github.com";
          description = "GitHub API URL for MCP";
        };
        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to the sops-nix secret file containing the GitHub token";
        };
      };
      config = {
        programs.mcpservers = {
          sqlite = {command = "${pkgs.mcp-server-sqlite}/bin/mcp-server-sqlite";};
          fetch = {command = "${pkgs.mcp-server-fetch}/bin/mcp-server-fetch";};
          github = {
            command =
              if config.igix.mcp.gh.tokenFile != null
              then
                toString (pkgs.writeShellScript "mcp-github-wrapper" ''
                  export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.igix.mcp.gh.tokenFile})
                  exec ${pkgs.mcp-server-github}/bin/mcp-server-github "$@"
                '')
              else "${pkgs.mcp-server-github}/bin/mcp-server-github";
            env = {
              GITHUB_API_URL = config.igix.mcp.gh.url;
            };
          };
          sequence = {command = "${pkgs.mcp-server-sequence}/bin/mcp-server-sequence";};
          context7 = {command = "${pkgs.mcp-server-context7}/bin/mcp-server-context7";};
          pdf = {command = "${pkgs.mcp-server-pdf}/bin/mcp-server-pdf";};
          arxiv = {command = "${pkgs.mcp-server-arxiv}/bin/mcp-server-arxiv";};
        };
      };
    };
    claude-code = {
      pkgs,
      config,
      lib,
      ...
    }:
      commonConfig {
        inherit pkgs lib;
        isAntigravity = false;
      };
    antigravity = {
      pkgs,
      config,
      lib,
      ...
    }:
      commonConfig {
        inherit pkgs lib;
        isAntigravity = true;
      };
  };
}
