{
  inputs,
  self,
  ...
}: {
  flake.homeModules.nixpkgs = {
    nixpkgs = {
      overlays = [
        self.overlays.stable-pkgs
        self.overlays.pdf-mcp
        inputs.nur.overlays.default
      ];
      config.allowUnfree = true;
    };
  };
}
