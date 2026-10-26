{...}: {
  # Lets Claude Code's WebFetch read vetted documentation hosts without asking,
  # in every permission mode, and makes every other fetch ask.
  #
  # What a fetch can leak is whatever the URL carries. Arbitrary hosts are out:
  # a hostname alone can carry data (<data>.attacker.example). On an allowlisted
  # host the path still reaches that host's operator, so the list should only
  # hold operators you trust with an odd page name. The query is constrained per
  # host: none by default, any, or named parameters whose values must match.
  flake.homeModules.claude-web-fetch = {
    pkgs,
    lib,
    config,
    ...
  }: let
    cfg = config.igix.claudeCode.webFetch;
    rules = pkgs.writeText "claude-web-fetch-rules.json" (builtins.toJSON {
      inherit (cfg) maxUrlLength;
      hosts =
        lib.mapAttrs (_: host: {inherit (host) subdomains query;})
        (lib.filterAttrs (_: host: host.enable) cfg.hosts);
    });
    gate = pkgs.writers.writePython3Bin "claude-web-fetch-gate" {
      flakeIgnore = ["E501"];
    } (builtins.readFile ./web-fetch-gate.py);
  in {
    options.igix.claudeCode.webFetch = {
      enable =
        lib.mkEnableOption ''
          a PreToolUse hook that approves WebFetch for allowlisted hosts and makes
          every other WebFetch ask, whatever the permission mode
        ''
        // {default = true;};

      maxUrlLength = lib.mkOption {
        type = lib.types.ints.positive;
        default = 512;
        description = "Longer URLs ask, so even an allowlisted host can be sent little.";
      };

      hosts = lib.mkOption {
        default = {};
        description = ''
          Hosts WebFetch may read without asking, keyed by hostname. Only https
          on the default port, without credentials, is ever approved. The entry
          with the longest matching name decides, so a subdomain can override its
          domain. The defaults are ordinary definitions, so entries added
          elsewhere merge with them; set `enable = false` to drop one.
        '';
        example = lib.literalExpression ''
          {
            "example.org" = {};                      # any path, no query
            "search.example.org".query.q = "[a-z0-9-]{1,40}";
            "intranet.example".query = "any";       # trusted with anything
          }
        '';
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether this entry applies.";
            };
            subdomains = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Also match every subdomain of this host.";
            };
            query = lib.mkOption {
              type = lib.types.either (lib.types.enum ["none" "any"]) (lib.types.attrsOf lib.types.str);
              default = "none";
              description = ''
                What the query string may hold: `"none"` (asks if there is one),
                `"any"`, or an attribute set of allowed parameter names, each
                mapped to a Python regular expression its decoded value must fully
                match. A parameter not listed asks.
              '';
            };
          };
        });
      };
    };

    config = lib.mkIf cfg.enable {
      # Public reference documentation run by the projects themselves.
      igix.claudeCode.webFetch.hosts =
        lib.genAttrs [
          "arxiv.org"
          "crates.io"
          "csrc.nist.gov"
          "ctan.org"
          "developer.mozilla.org"
          "doc.rust-lang.org"
          "doc.sagemath.org"
          "docs.claude.com"
          "code.claude.com"
          "docs.python.org"
          "docs.rs"
          "iacr.org"
          "ietf.org"
          "kernel.org"
          "man.archlinux.org"
          "man7.org"
          "nix.dev"
          "nixos.org"
          "nvlpubs.nist.gov"
          "openssl.org"
          "peps.python.org"
          "pypi.org"
          "rfc-editor.org"
          "rust-lang.org"
          "strongswan.org"
          "wiki.archlinux.org"
          "wireguard.com"
        ] (_: {})
        // {
          # GitHub Pages is anyone's host; only this project's own pages.
          "nix-community.github.io".subdomains = false;
        };

      programs.claude-code.settings.hooks.PreToolUse = [
        {
          matcher = "WebFetch";
          hooks = [
            {
              type = "command";
              command = "${gate}/bin/claude-web-fetch-gate ${rules}";
            }
          ];
        }
      ];
    };
  };
}
