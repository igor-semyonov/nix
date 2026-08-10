{...}: {
  flake.homeModules.claude = {...}: {
    programs.claude-code = {
      enable = true;
      lspServers = {
        rust = {
          args = [
            "--stdio"
          ];
          command = "rust-analyzer";
          extensionToLanguage = {
            ".rs" = "rust";
          };
        };
      };
    };
  };
}
