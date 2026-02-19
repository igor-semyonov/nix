{
  inputs,
  lib,
  config,
  usersToNixos,
  ...
}: {
  _module.args.buildNixos = {
    hostname,
    system ? "x86_64-linux",
    includedUsers ? ["igor"],
    modules ? [],
    hardware-configuration ? {},
    groups ? {},
  }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules =
        modules
        ++ [
          (
            {pkgs, ...}: {
              networking.hostName = hostname;
              users = {
                users = usersToNixos pkgs (lib.filterAttrs (n: v: lib.elem n includedUsers) config.users);
                groups = groups;
              };
            }
          )
          hardware-configuration
        ];
    };
}
