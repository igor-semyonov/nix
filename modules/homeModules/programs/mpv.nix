{...}: {
  flake.homeModules.mpv = {
    pkgs,
    lib,
    ...
  }: {
    programs.mpv = {
      enable = true;
      scripts = lib.optionals pkgs.stdenv.isLinux [pkgs.mpvScripts.mpris];
    };
  };
}
