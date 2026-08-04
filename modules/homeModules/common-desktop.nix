{
  inputs,
  self,
  ...
}: {
  flake.homeModules.common-desktop = {pkgs, ...}: {
    imports = [
      self.homeModules.common
      inputs.tokyonight.homeManagerModules.default
    ];

    tokyonight = {
      enable = true;
      style = "storm"; # Options: "night", "storm", "moon", or "day"
    };

    home.packages = with pkgs;
      [
        bibata-cursors
        papirus-nord
      ]
      ++ lib.optionals pkgs.stdenv.isDarwin [
        # colima
        # docker
        # hidden-bar
        # raycast
      ]
      ++ lib.optionals (!pkgs.stdenv.isDarwin) [
        pavucontrol
        tesseract
      ];
  };
}
