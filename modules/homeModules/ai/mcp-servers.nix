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
    # Runs github-mcp-server against exactly `gh.host`. gh and the server both let the
    # environment override their configuration -- an env token beats the per-host login,
    # an inherited GITHUB_HOST the default host -- so all GH_*/GITHUB_* go first.
    githubServer = pkgs.writeShellApplication {
      name = "github-mcp-server-scoped";
      runtimeInputs = [pkgs.coreutils pkgs.github-mcp-server] ++ lib.optional cfg.gh.useGhCli pkgs.gh;
      text = ''
        for var in "''${!GH_@}" "''${!GITHUB_@}"; do unset "$var"; done
        host=${lib.escapeShellArg cfg.gh.host}
        ${
          if cfg.gh.useGhCli
          then ''token=$(gh auth token --hostname "$host")''
          else ''token=$(cat -- ${lib.escapeShellArg cfg.gh.tokenFile})''
        }
        if [ -z "$token" ]; then
          echo "github-mcp-server: empty token for $host" >&2
          exit 1
        fi
        export GITHUB_HOST="https://$host" GITHUB_PERSONAL_ACCESS_TOKEN="$token"
        exec github-mcp-server "$@"
      '';
    };
    # Servers with no business on the network. On Linux each runs under bwrap in new user
    # and network namespaces: no IP beyond bwrap's own loopback, no nscd or resolved (so no DNS), and
    # /run/user/<uid> (session bus, agents -- so no commit signing), /run/dbus and
    # /run/podman hidden. Only `offlineEnv`, LC_* and the server's `env` get through; an
    # entry `env` outside that fails evaluation rather than vanish. Not a sandbox against
    # a hostile server: same uid, whole filesystem, every other socket. Darwin runs them
    # unwrapped; fetch, github and playwright need the network and are never wrapped.
    offlineEnv = ["HOME" "USER" "LOGNAME" "PATH" "LANG" "TZ" "TZDIR" "TERM" "TMPDIR" "XDG_CONFIG_HOME" "XDG_CACHE_HOME" "XDG_DATA_HOME" "XDG_STATE_HOME"];
    offlineServers = {
      # Git repository inspection and operations.
      git = {
        pkg = pkgs.mcp-server-git;
        bin = "mcp-server-git";
        env = [];
      };
      # Persistent knowledge graph memory across sessions.
      memory = {
        pkg = pkgs.mcp-server-memory;
        bin = "mcp-server-memory";
        env = ["MEMORY_FILE_PATH"];
      };
      # Structured step-by-step reasoning scratchpad.
      sequential-thinking = {
        pkg = pkgs.mcp-server-sequential-thinking;
        bin = "mcp-server-sequential-thinking";
        env = ["DISABLE_THOUGHT_LOGGING"];
      };
      # Timezone-aware current time / conversions.
      time = {
        pkg = pkgs.mcp-server-time;
        bin = "mcp-server-time";
        env = [];
      };
      # Extract text / tables / images from PDFs (OCR via tesseract). URL inputs fail.
      # FastMCP otherwise asks pypi.org for a newer release at every start.
      pdf = {
        pkg = pkgs.pdf-mcp;
        bin = "pdf-mcp";
        env = ["PDF_MCP_CACHE_DIR" "PDF_MCP_CACHE_TTL" "PDF_MCP_MAX_WORKERS" "FASTMCP_CHECK_FOR_UPDATES"];
        setEnv.FASTMCP_CHECK_FOR_UPDATES = "off";
      };
    };
    offline = {
      pkg,
      bin,
      env,
      ...
    }:
      if pkgs.stdenv.hostPlatform.isLinux
      then
        toString (pkgs.writeShellScript "${bin}-offline" ''
          keep=()
          for var in ${toString offlineEnv} "''${!LC_@}" ${toString env}; do
            # Exported only: bash itself sets PATH and TERM when they are not.
            if [[ ''${!var@a} == *x* ]]; then keep+=("$var=''${!var}"); fi
          done
          masks=()
          for dir in /run/nscd /run/systemd/resolve "/run/user/$UID" /run/dbus /run/podman; do
            if [ -e "$dir" ]; then masks+=(--tmpfs "$dir"); fi
          done
          exec ${pkgs.bubblewrap}/bin/bwrap --unshare-user --unshare-net --die-with-parent \
            --dev-bind / / "''${masks[@]}" \
            -- ${pkgs.coreutils}/bin/env -i "''${keep[@]}" ${pkg}/bin/${bin} "$@"
        '')
      else "${pkg}/bin/${bin}";
  in {
    imports = [
      (lib.mkRemovedOptionModule ["igix" "mcp" "gh" "url"] ''
        Set igix.mcp.gh.host to the bare hostname instead. github-mcp-server never read
        the URL, so every request went to github.com.
      '')
    ];

    options.igix.mcp = {
      enable = lib.mkEnableOption "Enable the shared MCP server catalogue.";

      gh = {
        host = lib.mkOption {
          type = lib.types.strMatching "[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*(:[0-9]{1,5})?";
          default = "github.com";
          example = "github.example.com";
          description = ''
            Host the github MCP server talks to: github.com, a GitHub Enterprise
            Server hostname or a ghe.com tenant. A bare lowercase hostname with an
            optional `:port`, no scheme or path. The server always gets
            `GITHUB_HOST=https://<host>`, and its token is the one `useGhCli` or
            `tokenFile` provides for this host.

            Either way the server starts through a wrapper that first unsets every
            GH_* and GITHUB_* variable it inherits. That includes github-mcp-server's
            own settings, which it reads as GITHUB_<KEY> (GITHUB_READ_ONLY,
            GITHUB_TOOLSETS, ...), so give those as flags in
            `programs.mcp.servers.github.args` (`--read-only`, `--toolsets=...`). Evaluation fails if the github
            entry's `env` has a GH_*/GITHUB_* other than this GITHUB_HOST, or its
            `args` set `--gh-host`.
          '';
        };
        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.externalPath;
          default = null;
          description = ''
            Absolute path, as a string outside the Nix store, of a file holding a
            GitHub personal access token for `host`
            (e.g. `config.sops.secrets.github-token.path`). A Nix path value, which
            would be copied into the world-readable store, and a store path are
            rejected. The server's wrapper reads the file at every start and refuses
            to start when it is missing, unreadable or empty; an inherited
            GITHUB_PERSONAL_ACCESS_TOKEN is ignored (see `host`). Ignored when
            `useGhCli` is set.

            Prefer `useGhCli` if your org disallows creating PATs.
          '';
        };
        useGhCli = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Authenticate the github MCP server with the GitHub CLI's stored login
            for `host` instead of a PAT. The wrapper runs
            `gh auth token --hostname <host>` at every start with all GH_* and
            GITHUB_* variables removed (see `host`), so GH_TOKEN, GITHUB_TOKEN,
            GH_ENTERPRISE_TOKEN, GITHUB_ENTERPRISE_TOKEN, GH_HOST and GH_CONFIG_DIR
            are ignored: the token can only come from that host's login in
            `$XDG_CONFIG_HOME/gh` (else `~/.config/gh`) or the keyring, and without
            one the server does not start. No token is written to disk or the Nix
            store.

            This uses the `gh` OAuth app flow (run `gh auth login --hostname <host>`
            once), which is a distinct mechanism from personal access tokens and is
            commonly permitted even when an org blocks PAT creation.

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
      assertions = let
        github = config.programs.mcp.servers.github;
        githubEnv = lib.filterAttrs (var: _: lib.hasPrefix "GH_" var || lib.hasPrefix "GITHUB_" var) github.env;
      in
        lib.optionals (cfg.gh.useGhCli || cfg.gh.tokenFile != null) [
          {
            assertion = githubEnv == {GITHUB_HOST = "https://${cfg.gh.host}";};
            message = ''
              igix.mcp: programs.mcp.servers.github.env may hold no GH_* or GITHUB_* variable
              but GITHUB_HOST = "https://${cfg.gh.host}"; it has ${lib.concatStringsSep ", " (lib.attrNames githubEnv)}.
              The wrapper unsets every GH_* and GITHUB_* before github-mcp-server starts, so
              the rest would be dropped without a word. Give server settings as flags in
              programs.mcp.servers.github.args (--read-only, --lockdown-mode, --toolsets,
              --exclude-tools) and the host as igix.mcp.gh.host.
            '';
          }
          {
            # The flag beats the GITHUB_HOST the wrapper exports.
            assertion = !lib.any (arg: lib.hasPrefix "--gh-host" (lib.replaceStrings ["_"] ["-"] arg)) github.args;
            message = ''
              igix.mcp: programs.mcp.servers.github.args sets --gh-host, which would send the
              token for igix.mcp.gh.host (${cfg.gh.host}) to another host. Set igix.mcp.gh.host
              instead.
            '';
          }
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux (lib.mapAttrsToList (name: server: let
            passed = offlineEnv ++ server.env;
            dropped = lib.filter (var: !(lib.elem var passed || lib.hasPrefix "LC_" var)) (lib.attrNames config.programs.mcp.servers.${name}.env);
          in {
            assertion = dropped == [];
            message = ''
              igix.mcp: programs.mcp.servers.${name}.env sets ${lib.concatStringsSep ", " dropped},
              which its bwrap wrapper does not pass on: only ${toString passed} and LC_* reach
              the server.
            '';
          })
          offlineServers);

      programs.mcp = {
        enable = true;
        servers =
          lib.mapAttrs (_: server: {
            command = offline server;
            env = server.setEnv or {};
          })
          offlineServers
          // {
            # Fetch arbitrary URLs and return their content as markdown.
            fetch = {command = "${pkgs.mcp-server-fetch}/bin/mcp-server-fetch";};
            # Deliberately absent — both ship the query itself to a third party:
            #   context7 -> context7.com, clerk.context7.com
            #   mcp-nixos -> api.flakehub.com, cache.nixos.org, nix.dev,
            #                noogle.dev, nix-community.github.io,
            #                nix-darwin.github.io, api.github.com
            # Nix questions are answered from the local nixpkgs clone instead;
            # see rules/nix-style.md and the `nixpkgs-local` skill. That also
            # reflects the pinned rev rather than whatever search.nixos.org
            # has indexed.
          }
          # GitHub API server. Auth precedence: gh CLI OAuth token > PAT file.
          # SSH keys are not an option (the server uses the HTTPS API).
          // lib.optionalAttrs (cfg.gh.useGhCli || cfg.gh.tokenFile != null) {
            github = {
              command = "${githubServer}/bin/github-mcp-server-scoped";
              args = ["stdio"];
              # The wrapper sets it regardless; stated here so every generated config
              # shows which host the server is for.
              env.GITHUB_HOST = "https://${cfg.gh.host}";
            };
          }
          // lib.optionalAttrs cfg.playwright.enable {
            playwright = {command = "${pkgs.playwright-mcp}/bin/playwright-mcp";};
          };
      };
    };
  };
}
