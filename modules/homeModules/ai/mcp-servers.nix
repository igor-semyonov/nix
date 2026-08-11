{self, ...}: {
  # Central MCP server catalogue consumed by every AI TUI via
  # `enableMcpIntegration`. Writes the canonical config to
  # `$XDG_CONFIG_HOME/mcp/mcp.json` (programs.mcp) and, through each TUI's
  # integration flag, into its own config too.
  flake.homeModules.mcp-servers = {
    pkgs,
    lib,
    config,
    ...
  }: let
    cfg = config.igix.mcp;
    # Runs the github MCP server with a token minted from the local `gh` login
    # (OAuth), avoiding PATs entirely. `gh auth token` errors non-zero when not
    # logged in, and `set -e` propagates that so the failure is visible.
    ghCliWrapper = pkgs.writeShellApplication {
      name = "github-mcp-server-gh";
      runtimeInputs = [pkgs.gh pkgs.github-mcp-server];
      text = ''
        GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token)
        export GITHUB_PERSONAL_ACCESS_TOKEN
        exec github-mcp-server "$@"
      '';
    };
  in {
    options.igix.mcp = {
      enable = lib.mkEnableOption "Enable the shared MCP server catalogue.";

      gh = {
        url = lib.mkOption {
          type = lib.types.str;
          default = "https://api.github.com";
          description = "GitHub API URL for the github MCP server.";
        };
        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to a file containing a GitHub personal access token
            (e.g. `config.sops.secrets.github-token.path`). The mcp module
            reads the file at startup via its `env.<VAR>.file` support, so the
            token never lands in the Nix store.

            Prefer `useGhCli` if your org disallows creating PATs.
          '';
        };
        useGhCli = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Authenticate the github MCP server with the GitHub CLI's OAuth
            token instead of a PAT. When true, the server is wrapped so that
            `GITHUB_PERSONAL_ACCESS_TOKEN` is set from `gh auth token` at
            startup — no token is ever written to disk or the Nix store.

            This uses the `gh` OAuth app flow (run `gh auth login` once), which
            is a distinct mechanism from personal access tokens and is commonly
            permitted even when an org blocks PAT creation.

            Takes precedence over `tokenFile` when both are set.
          '';
        };
      };

      playwright.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the playwright (browser automation) MCP server. Pulls in a Chromium; off by default.";
      };
    };

    config = lib.mkIf cfg.enable {
      programs.mcp = {
        enable = true;
        servers =
          {
            # Fetch arbitrary URLs and return their content as markdown.
            fetch = {command = "${pkgs.mcp-server-fetch}/bin/mcp-server-fetch";};
            # Git repository inspection and operations.
            git = {command = "${pkgs.mcp-server-git}/bin/mcp-server-git";};
            # Persistent knowledge graph memory across sessions.
            memory = {command = "${pkgs.mcp-server-memory}/bin/mcp-server-memory";};
            # Structured step-by-step reasoning scratchpad.
            sequential-thinking = {command = "${pkgs.mcp-server-sequential-thinking}/bin/mcp-server-sequential-thinking";};
            # Timezone-aware current time / conversions.
            time = {command = "${pkgs.mcp-server-time}/bin/mcp-server-time";};
            # Up-to-date library docs lookup.
            context7 = {command = "${pkgs.context7-mcp}/bin/context7-mcp";};
            # Query NixOS options and nixpkgs packages.
            nixos = {command = "${pkgs.mcp-nixos}/bin/mcp-nixos";};
            # Extract text / tables / images from PDFs (OCR via tesseract).
            pdf = {command = "${pkgs.pdf-mcp}/bin/pdf-mcp";};
          }
          # GitHub API server. Auth precedence: gh CLI OAuth token > PAT file.
          # SSH keys are not an option (the server uses the HTTPS API).
          // lib.optionalAttrs cfg.gh.useGhCli {
            github = {
              # Wrap the server so its token is minted from the existing
              # `gh` login at startup. `gh auth token` fails loudly if not
              # logged in, so a missing session surfaces instead of a silent
              # unauthenticated server.
              command = "${ghCliWrapper}/bin/github-mcp-server-gh";
              args = ["stdio"];
              env.GITHUB_API_URL = cfg.gh.url;
            };
          }
          // lib.optionalAttrs (!cfg.gh.useGhCli && cfg.gh.tokenFile != null) {
            github = {
              command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
              args = ["stdio"];
              env = {
                GITHUB_API_URL = cfg.gh.url;
                GITHUB_PERSONAL_ACCESS_TOKEN.file = cfg.gh.tokenFile;
              };
            };
          }
          // lib.optionalAttrs cfg.playwright.enable {
            playwright = {command = "${pkgs.playwright-mcp}/bin/playwright-mcp";};
          };
      };
    };
  };
}
