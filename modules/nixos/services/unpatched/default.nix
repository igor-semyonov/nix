{
  pkgs,
  lib,
  ...
}: {
  programs = {
    nix-ld = {
      enable = true;
      libraries = with pkgs;
        [
          stdenv.cc.cc.lib
          cudaPackages.cudatoolkit.lib
          cudaPackages.cudnn
          linuxPackages.nvidia_x11
          zlib
          glib
          openssl

          # matplotlib and pyside6
          libGL
          libxkbcommon
          fontconfig
          libx11
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
        ]
        ++ pythonManylinuxPackages.manylinux1
        ++ lib.optionals (pkgs.system == "x86_64-linux") (with pkgs.cudaPackages; [
          libcutensor
          nccl
        ]);
    };
  };

  services = {
    envfs = {
      enable = true;
    };
  };
}
