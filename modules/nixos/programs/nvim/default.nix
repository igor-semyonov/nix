{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    inputs.my-nvim.packages.${pkgs.system}.nvim-nixcats
  ];
}
