{...}: {
  flake.homeModules.mpv = {
    pkgs,
    lib,
    ...
  }: {
    programs.mpv = {
      enable = true;
      scripts = lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.mpvScripts.mpris];
    };
  };
}
