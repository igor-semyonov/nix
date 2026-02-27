{
  inputs,
  self,
  ...
}: {
  flake.homeModules.nixpkgs = {
    nixpkgs = {
      overlays = [
        self.overlays.stable-pkgs
        inputs.nur.overlays.default
      ];
      config.allowUnfree = true;
    };
  };
}
