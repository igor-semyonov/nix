# Shared host/user plumbing, consumed as a flake-parts module rather than as
# values. Underscore-prefixed so import-tree skips it (`andNot (hasInfix "/_")`)
# — it must be imported explicitly, by this flake and by consumers alike, so
# that `config.users` resolves against the *importing* flake's module tree.
# Each repo declares its own users; nothing here knows about any of them.
{
  inputs,
  withSystem,
  lib,
  config,
  ...
}: let
  # A user's NixOS `users.users.<name>` entry. Well-known fields are typed; the
  # freeform type keeps every other NixOS user option available without
  # enumerating it here.
  nixosUserModule = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      name = lib.mkOption {
        type = lib.types.singleLineStr;
        description = "The user's login name.";
      };
      isNormalUser = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this is a normal (interactive) user.";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Display / full name (GECOS).";
      };
      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
        default = [];
        description = "Additional groups the user is a member of.";
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Packages installed for this user outside of home-manager.";
      };
    };
  };

  homeUserModule = lib.types.submodule {
    options = {
      modules = lib.mkOption {
        type = lib.types.listOf lib.types.deferredModule;
        default = [];
        description = "Home-manager modules composing this user's home configuration.";
      };
    };
  };

  userModule = lib.types.submodule {
    options = {
      nixos = lib.mkOption {
        description = "NixOS `users.users.<name>` definition for this user.";
        type = nixosUserModule;
      };
      home = lib.mkOption {
        description = "Home-manager configuration passed to homeManagerConfiguration.";
        type = homeUserModule;
      };
    };
  };

  usersToNixos = pkgs: hostname: users: (
    lib.mapAttrs (n: v: (v pkgs hostname).nixos)
    users
  );
  filterUsers = users: includedUsers: (lib.filterAttrs (n: v: lib.elem n includedUsers) users);

  buildNixos = {
    hostname,
    system ? "x86_64-linux",
    includedUsers ? [],
    nixosModules ? [],
    nixosVmModules ? [],
    homeModules ? [],
    hardware-configuration ? {},
    groups ? {},
    nixosHomeManagerModule ? false,
  }: {
    perSystem = {...}: {
      packages."${hostname}-vm" = let
        vm = config.flake.nixosConfigurations.${hostname}.extendModules {modules = nixosVmModules;};
      in
        vm.config.system.build.vm;
    };
    flake = {
      nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
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
    };
  };

  buildHome = {
    hostname,
    system ? "x86_64-linux",
    includedUsers ? [],
    homeModules ? [],
  }: {
    flake.homeConfigurations = withSystem system (
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
  };

  buildNixosAndHomeManager = {
    hostname,
    system ? "x86_64-linux",
    includedUsers ? [],
    nixosModules ? [],
    nixosVmModules ? [],
    homeModules ? [],
    hardware-configuration ? {},
    groups ? {},
    nixosHomeManagerModule ? false,
  }:
    lib.recursiveUpdate
    (buildNixos {
      inherit
        system
        hostname
        includedUsers
        nixosModules
        nixosVmModules
        homeModules
        hardware-configuration
        groups
        nixosHomeManagerModule
        ;
    })
    (buildHome {
      inherit
        system
        hostname
        includedUsers
        homeModules
        ;
    });
in {
  options.users = lib.mkOption {
    default = {};
    description = "Users, as a function of pkgs and hostname.";
    type = lib.types.attrsOf (lib.types.functionTo (lib.types.functionTo userModule));
  };

  config._module.args = {
    inherit
      buildNixos
      buildHome
      buildNixosAndHomeManager
      usersToNixos
      filterUsers
      ;
  };
}
