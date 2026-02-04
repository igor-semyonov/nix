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

  programs.bash.enable = true;

  environment.systemPackages = [
  ];

  # Fonts configuration
  # fonts.packages = with pkgs; [
  #   nerd-fonts.meslo-lg
  # ];

  nix.linux-builder = {
    enable = true;
    ephemeral = true; # Wipes the VM on restart (optional, keeps it clean)
    maxJobs = 4;
    config = {
      virtualisation.cores = 4;
      virtualisation.memorySize = 8192; # Give it 8GB+ RAM for CUDA builds!
    };
  };

  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";
}
