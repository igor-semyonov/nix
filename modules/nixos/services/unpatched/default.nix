{pkgs, ...}: {
  programs = {
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        cudaPackages.cudatoolkit.lib
        zlib
      ];
      # ++ extra-libs;
    };
  };

  services = {
    envfs = {
      enable = true;
    };
  };
}
