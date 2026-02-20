{config, ...}: {
  flake.nixosModules.programs-prism-launcher = {
    pkgs,
    lib,
    includedUsers,
    ...
  }: {
    users.users = lib.mapAttrs (n: v: {packages = [pkgs.prismlauncher];}) (lib.filterAttrs (n: v: lib.elem n includedUsers) config.users);
  };
}
