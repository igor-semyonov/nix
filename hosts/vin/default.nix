{
  pkgs,
  nixosModules,
  ...
}: {
  imports = [
    "${nixosModules}/programs/nvim"
  ];
  # Nix settings
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
    };
    optimise.automatic = true;
    package = pkgs.nix;
  };

  environment.systemPackages = [
  ];

  # Fonts configuration
  # fonts.packages = with pkgs; [
  #   nerd-fonts.meslo-lg
  # ];

  system.stateVersion = 6;
}
