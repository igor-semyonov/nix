{
  self,
  ...
}: {
  flake.homeModules.common-headless = {
    pkgs,
    ...
  }: {
    imports = [self.homeModules.common];

    # Ensure common packages are installed
    home.packages = with pkgs;
      [
      ]
      ++ lib.optionals pkgs.stdenv.isDarwin [
      ]
      ++ lib.optionals (!pkgs.stdenv.isDarwin) [
      ];
  };
}
