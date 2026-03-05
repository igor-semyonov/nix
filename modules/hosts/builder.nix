{
  self,
  buildNixos,
  buildHome,
  inputs,
  withSystem,
  lib,
  config,
  usersToNixos,
  filterUsers,
  ...
}: {
  _module.args.buildNixosAndHomeManager = {
    hostname,
    system ? "x86_64-linux",
    includedUsers ? ["igor"],
    nixosModules ? [],
    homeModules ? [],
    hardware-configuration ? {},
    groups ? {},
    nixosHomeManagerModule ? false,
  }: {
    perSystem = {...}: {
      packages."${hostname}-vm" = self.outputs.nixosConfigurations.${hostname}.config.system.build.vm;
    };
    flake = {
      nixosConfigurations.${hostname} = buildNixos {
        inherit
          system
          hostname
          includedUsers
          nixosModules
          homeModules
          hardware-configuration
          groups
          nixosHomeManagerModule
          ;
      };
      homeConfigurations = buildHome {
        inherit
          system
          hostname
          includedUsers
          homeModules
          ;
      };
    };
  };

  _module.args.buildNixos = {
    hostname,
    system ? "x86_64-linux",
    includedUsers ? ["igor"],
    nixosModules ? [],
    homeModules ? [],
    hardware-configuration ? {},
    groups ? {},
    nixosHomeManagerModule ? false,
  }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit includedUsers;};
      modules =
        nixosModules
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
            nixpkgs.overlays = [inputs.nur.overlays.default];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              users =
                lib.mapAttrs (n: v: {
                  imports = (v pkgs hostname).home.modules ++ homeModules;
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
    homeModules ? [],
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
                  {modules = homeModules;}
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
