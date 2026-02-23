{...}: {
  flake.homeModules.mpv = {pkgs, ...}: {
    programs.mpv = {
      enable = true;
      scripts = [pkgs.mpvScripts.mpris];
    };
  };
}
