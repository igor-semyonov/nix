{pkgs, ...}: {
  programs = {
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        cudaPackages.cudatoolkit.lib
        linuxPackages.nvidia_x11

        # matplotlib and pyside6
        pkgs.libGL
        pkgs.libxkbcommon
        pkgs.fontconfig
        pkgs.libx11
        pkgs.glib
        pkgs.freetype
        pkgs.dbus
      ];
    };
  };

  services = {
    envfs = {
      enable = true;
    };
  };
}
