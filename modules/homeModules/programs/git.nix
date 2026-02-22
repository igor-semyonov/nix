{...}: {
  flake.homeModules.git = {userConfig, ...}: {
    programs = {
      git = {
        enable = true;
        settings = {
          user = {
            name = userConfig.fullName;
            email = userConfig.email;
          };
          pull.rebase = "true";
        };
        signing = {
          key = userConfig.gitKey;
          signByDefault = true;
        };
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
