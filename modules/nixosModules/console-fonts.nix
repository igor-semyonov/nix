{...}: {
  flake.nixosModules.console-fonts = {pkgs, ...}: {
    console = {
      # Terminus tops out at 16x32; spleen ships a precompiled 32x64 .psfu,
      # the largest the VT driver accepts. Costs box-drawing coverage (35
      # U+25xx glyphs vs Terminus's 58) -- TUI borders may fall back to ASCII.
      packages = [pkgs.spleen];
      font = "${pkgs.spleen}/share/consolefonts/spleen-32x64.psfu";
      enable = true;
      keyMap = "us";
      earlySetup = true;
      # useXkbConfig = true; # use xkb.options in tty.
    };
  };
}
