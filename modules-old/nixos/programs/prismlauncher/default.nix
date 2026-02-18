{
  pkgs,
  userConfig,
  ...
}: {
  users.users.${userConfig.name}.packages = [pkgs.prismlauncher];
}
