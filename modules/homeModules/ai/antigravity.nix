{self, ...}: {
  flake.homeModules.antigravity = {
    pkgs,
    config,
    lib,
    ...
  }: let
    inherit (import ./_lib.nix {inherit pkgs lib self;}) contextText;
  in {
    programs.antigravity-cli = {
      enable = true;

      # Pull the shared MCP catalogue into ~/.gemini/config/mcp_config.json.
      enableMcpIntegration = true;

      # antigravity-cli's context is an attrset: <name> -> file body, written
      # to ~/.gemini/<name>.md.
      context = {
        GEMINI = contextText;
      };

      # antigravity-native settings only (no statusLine/outputStyles here).
      settings = {
        toolPermission = "proceed-in-sandbox";
      };

      # Same skills tree as Claude Code; symlinked under the antigravity skills dir.
      skills = ./skills;
    };
  };
}
