{self, ...}: {
  flake.nixosModules.igix-desktop = {
    imports = with self.nixosModules; [
      common-desktop
      kde
      nix-ld
    ];
  };
}
