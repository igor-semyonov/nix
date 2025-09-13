{
  pkgs,
  lib,
  ...
}: {
  programs = {
    ssh = {
      enable = true;
    };
    ssh-agent.enable = true;
  };
}
