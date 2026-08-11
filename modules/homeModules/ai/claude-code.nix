{self, ...}: {
  flake.homeModules.claude-code = {
    pkgs,
    config,
    lib,
    ...
  }: let
    inherit (import ./_lib.nix {inherit pkgs lib self;}) contextText mkStatusline;
    inherit (mkStatusline "claude-code") statuslineName statusline;
  in {
    home.packages = [statusline];

    programs.claude-code = {
      enable = true;

      # Pull the shared MCP catalogue (programs.mcp.servers) into Claude Code.
      # Requires programs.mcp.enable, provided by the mcp-servers module.
      enableMcpIntegration = true;

      context = contextText;

      settings = {
        mouse = false;
        includeCoAuthoredBy = false;
        cleanupPeriodDays = 30;
        statusLine = {
          type = "command";
          command = statuslineName;
        };
        permissions = {
          allow = [
            "Bash(cargo:*)"
            "Bash(nix:*)"
            "Bash(rg:*)"
            "Bash(git diff:*)"
            "Bash(git status:*)"
            "Bash(git log:*)"
          ];
          ask = [
            "Bash(git push:*)"
          ];
          deny = [
            "Read(./.env)"
            "Read(./secrets/**)"
          ];
        };
        # Format after edits with `nix fmt`, which defers to whatever the
        # repo's flake declares (treefmt here: nix/lua/toml/yaml/markdown/shell).
        # `nix` is pinned to a nixpkgs store path so it is always present. Run in
        # the edited file's OWN flake (walk up to its nearest flake.nix), not the
        # session cwd, so cross-repo edits (e.g. ~/nix from a nix-personal
        # session) don't trip treefmt's "not inside the tree root" guard. If that
        # flake has no `formatter` output, this fails loudly with a clear message
        # rather than silently doing nothing (no `|| true`).
        hooks = {
          PostToolUse = [
            {
              matcher = "Edit|MultiEdit|Write";
              hooks = [
                {
                  type = "command";
                  command = ''
                    set -euo pipefail
                    f=$(${pkgs.jq}/bin/jq -r '.tool_input.file_path // empty')
                    [ -z "$f" ] && exit 0
                    d=$(${pkgs.coreutils}/bin/dirname "$f")
                    while [ "$d" != / ] && [ ! -e "$d/flake.nix" ]; do
                      d=$(${pkgs.coreutils}/bin/dirname "$d")
                    done
                    if [ ! -e "$d/flake.nix" ]; then
                      echo "no flake.nix above $f; skipping nix fmt" >&2
                      exit 0
                    fi
                    if ! err=$(cd "$d" && ${pkgs.nix}/bin/nix fmt "$f" 2>&1); then
                      echo "$err" >&2
                      echo "nix fmt failed: is a \`formatter\` output set up in $d/flake.nix?" >&2
                      exit 1
                    fi
                  '';
                }
              ];
            }
          ];
        };
      };

      # A skill is a directory containing SKILL.md; point at the whole tree.
      skills = ./skills;

      agentsDir = ./agents;
      commandsDir = ./commands;
      hooksDir = ./hooks;
      rulesDir = ./rules;

      outputStyles = {
        concise = ''
          Provide extremely concise, direct answers. Focus strictly on code and solutions.
        '';
        detailed = ''
          Provide comprehensive explanations of underlying concepts, especially for
          cryptography, algorithms, and Nix.
        '';
      };

      # Local, in-repo marketplace: builds offline, no fetch hashes needed.
      marketplaces = {
        igix = ./marketplace;
        # Remote marketplaces (opt-in): add a flake input, then reference it here.
        #   1. In flake.nix inputs:
        #        claude-marketplace = { url = "github:owner/repo"; flake = false; };
        #   2. Thread `inputs` into this module and uncomment:
        #        some-marketplace = inputs.claude-marketplace;
        #   3. `nix flake lock` and rebuild.
      };

      # Install the local plugins directly (each plugin is just a directory).
      # Plugin keys become personal-plugin directory names under skills/, so
      # they must not collide with any top-level skill name (hence
      # `latex-tools`, not `latex`, since a `latex` skill already exists).
      plugins = {
        deep-research = ./marketplace/plugins/deep-research;
        code-review = ./marketplace/plugins/code-review;
        rust-dev = ./marketplace/plugins/rust-dev;
        nix-dev = ./marketplace/plugins/nix-dev;
        latex-tools = ./marketplace/plugins/latex;
        crypto-research = ./marketplace/plugins/crypto-research;
      };
    };
  };
}
