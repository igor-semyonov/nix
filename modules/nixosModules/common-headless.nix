{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.common-headless = {pkgs, ...}: {
    imports = with self.nixosModules; [
      common
    ];
    igix.nvim.package = inputs.my-nvim.packages.${pkgs.stdenv.hostPlatform.system}.minimal;

    # Boot settings
    boot = {
      # kernelPackages = pkgs.linuxPackages_latest;
      consoleLogLevel = 0;

      # initrd.verbose = false;
      # kernelParams = ["quiet" "splash" "rd.udev.log_level=3"];
      # plymouth.enable = true;

      initrd.verbose = true;
      kernelParams = ["rd.udev.log_level=3"];
      plymouth.enable = false;
    };
  };
}
