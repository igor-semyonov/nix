{pkgs, ...}: {
  programs = {
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        cudaPackages.cudatoolkit.lib
        linuxPackages.nvidia_x11

        # matplotlib and pyside6
        libGL
        libxkbcommon
        fontconfig
        libx11
        glib
        freetype
        dbus
        kdePackages.wayland
        kdePackages.qtwayland
        xorg.xcbutil
        xorg.xcbutilcursor
        xorg.xcbutilwm
        xorg.xcbutilkeysyms
        xorg.xcbutilrenderutil
        xorg.xcbutilimage
        libxcb
        libdrm
      ];
    };
  };

  services = {
    envfs = {
      enable = true;
    };
  };
}
