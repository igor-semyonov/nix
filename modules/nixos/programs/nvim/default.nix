{
  pkgs,
  inputs,
  ...
}: {
  environment = {
    systemPackages = [
      inputs.my-nvim.packages.${pkgs.system}.nvim-nixcats
    ];
    variables = {
      EDITOR = "vim";
      VISUAL = "vim";
      SYSTEMD_EDITOR = "vim";
    };
  };
}
