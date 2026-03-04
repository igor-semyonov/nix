{...}: {
  flake.homeModules.git = {config, ...}: {
    programs = {
      git = {
        enable = true;
        settings = {
          user = {
            name = config.userConfig.fullName;
            email = config.userConfig.email;
          };
          pull.rebase = "true";
        };
        signing = {
          key = config.userConfig.gitKey;
          signByDefault = true;
        };
        lfs.enable = true;
      };
      delta = {
        enable = true;
        enableGitIntegration = true;
        options = {
          keep-plus-minus-markers = true;
          light = false;
          line-numbers = true;
          navigate = true;
          width = 70;
        };
      };
    };
  };
}
