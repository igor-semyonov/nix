{
  config,
  filterUsers,
  ...
}: {
  flake.nixosModules.programs-prism-launcher = {
    pkgs,
    lib,
    includedUsers,
    ...
  }: {
    users.users = lib.mapAttrs (n: v: {packages = [pkgs.prismlauncher];}) (filterUsers config.users includedUsers);
  };
}
