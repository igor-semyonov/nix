{pkgs, ...}: {
  programs = {
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        cudaPackages.cudatoolkit.lib
        linuxPackages.nvidia_x11
      ];
    };
  };

  services = {
    envfs = {
      enable = true;
    };
  };
}
