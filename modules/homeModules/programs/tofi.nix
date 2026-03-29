{...}: {
  flake.homeModules.tofi = {
    pkgs,
    osConfig,
    ...
  }: {
    programs.tofi = {
      enable = true;
      settings = {
        background-color = "#000000";
        border-width = 20;
        font = "${pkgs.nerd-fonts.fira-code}/share/fonts/truetype/NerdFonts/FiraCode/FiraCodeNerdFontPropo-Retina.ttf";
        font-size = 64;
        hint-font = false;
        height = "100%";
        width = "100%";
        num-results = 5;
        outline-width = 0;
        padding-top = "15%";
        padding-left = "15%";
        result-spacing = 32;

        selection-color = "#80FF80";
        selection-background = "#606060";
        selection-match-color = "#FF3030";
        selection-background-padding = "20";
        selection-background-corner-radius = 35;
      };
    };
  };
}
