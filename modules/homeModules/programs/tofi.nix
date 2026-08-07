{...}: {
  flake.homeModules.tofi = {
    pkgs,
    lib,
    ...
  }: {
    programs.tofi = {
      enable = true;
      settings = {
        background-color = lib.mkForce "#000000";
        border-width = 8;
        font = lib.mkForce "${pkgs.nerd-fonts.fira-code}/share/fonts/truetype/NerdFonts/FiraCode/FiraCodeNerdFontPropo-Retina.ttf";
        font-size = lib.mkForce 64;
        hint-font = false;
        height = "100%";
        width = "100%";
        num-results = 5;
        outline-width = 0;
        padding-top = "15%";
        padding-left = "15%";
        result-spacing = 32;

        selection-color = lib.mkForce "#80FF80";
        selection-background = lib.mkForce "#606060";
        selection-match-color = lib.mkForce "#FF3030";
        selection-background-padding = "20";
        selection-background-corner-radius = 35;
      };
    };
  };
}
