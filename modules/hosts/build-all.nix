{
  buildNixos,
  buildHome,
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
    flake.nixosConfigurations.${hostname} = buildNixos {
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
    flake.homeConfigurations = buildHome {
      inherit
        system
        hostname
        includedUsers
        homeModules
        ;
    };
  };
}
