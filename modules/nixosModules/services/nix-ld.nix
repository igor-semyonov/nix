{...}: {
  flake.nixosModules.nix-ld = {
    pkgs,
    config,
    lib,
    ...
  }: let
    cudaSupport = config.nixpkgs.config.cudaSupport or false;
  in {
    programs = {
      nix-ld = {
        enable = true;
        libraries = with pkgs;
          [
            stdenv.cc.cc.lib
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
            libxcb-util
            libxcb-cursor
            libxcb-wm
            libxcb-keysyms
            libxcb-render-util
            libxcb-image
            libxcb
            libdrm
          ]
          ++ lib.optionals cudaSupport [
            cudaPackages.cudatoolkit.lib
            cudaPackages.cudnn
            linuxPackages.nvidia_x11
          ]
          ++ pythonManylinuxPackages.manylinux1
          ++ lib.optionals (pkgs.system == "x86_64-linux" && cudaSupport) (with pkgs.cudaPackages; [
            libcutensor
            nccl
            libcusparse_lt
            libnvshmem
            libcufile
          ]);
      };
    };

    services = {
      envfs = {
        enable = true;
      };
    };
  };
}
