{
  inputs,
  withSystem,
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
      specialArgs = {inherit includedUsers;};
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

  _module.args.buildHome = {
    hostname,
    system ? "x86_64-linux",
    includedUsers ? ["igor"],
  }:
    withSystem system (
      {pkgs, ...}:
        builtins.listToAttrs (
          map ({
            name,
            value,
          }: {
            name = "${( value pkgs).home.extraSpecialArgs.userConfig.name}@${hostname}";
            value = inputs.home-manager.lib.homeManagerConfiguration ({
                inherit pkgs;
              }
              // (
                lib.zipAttrsWith (
                  n: v:
                    if builtins.isList (builtins.head v)
                    then builtins.concatLists v
                    else lib.last v
                ) [
                  {
                    modules = [
                      {
                        programs.home-manager.enable = true;
                        home.stateVersion = "25.05";
                      }
                    ];
                  }
                  (value pkgs).home
                ]
              ));
          })
          (
            lib.attrsToList
            (lib.filterAttrs (n: v: lib.elem n includedUsers) config.users)
          )
        )
    );
}
