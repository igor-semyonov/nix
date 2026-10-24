{
  inputs,
  self,
  ...
}: {
  flake.homeModules.common-desktop = {pkgs, ...}: {
    imports = [
      self.homeModules.common
    ];

    home.packages = with pkgs;
      []
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # colima
        # docker
        # hidden-bar
        # raycast
      ]
      ++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
        pavucontrol
        tesseract
      ];
  };
}
