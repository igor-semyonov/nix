{
  inputs,
  withSystem,
  lib,
  config,
  usersToNixos,
  filterUsers,
  ...
}: {
  _module.args.buildNixos = {
    hostname,
    system ? "x86_64-linux",
    includedUsers ? ["igor"],
    modules ? [],
    hardware-configuration ? {},
    groups ? {},
    nixosHomeManagerModule ? false,
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
                users = usersToNixos pkgs hostname (filterUsers config.users includedUsers);
                groups = groups;
              };
            }
          )
          hardware-configuration
        ]
        ++ lib.optional nixosHomeManagerModule
        (
          {pkgs, ...}: {
            imports = [inputs.home-manager.nixosModules.home-manager];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              users =
                lib.mapAttrs (n: v: {
                  imports = (v pkgs hostname).home.modules;
                })
                (filterUsers config.users includedUsers);
            };
          }
        );
    };

  _module.args.buildHome = {
    hostname,
    system ? "x86_64-linux",
    includedUsers ? ["igor"],
  }:
    withSystem system (
      {pkgs, ...}:
        builtins.listToAttrs (
          map ({value, ...}: {
            name = "${(value pkgs hostname).nixos.name}@${hostname}";
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
                  (value pkgs hostname).home
                ]
              ));
          })
          (
            lib.attrsToList
            (filterUsers config.users includedUsers)
          )
        )
    );
}
