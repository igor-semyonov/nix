{...}: {
  flake.nixosModules.console-fonts = {pkgs, ...}: {
    console = {
      # packages = [pkgs.terminus_font];
      font = "${pkgs.terminus_font}/share/consolefonts/ter-i32b.psf.gz";
      enable = true;
      keyMap = "us";
      earlySetup = true;
      # useXkbConfig = true; # use xkb.options in tty.
    };
  };
}
