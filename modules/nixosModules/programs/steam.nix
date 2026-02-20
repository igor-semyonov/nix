{config, ...}: {
  flake.nixosModules.programs-steam = {
    pkgs,
    lib,
    includedUsers,
    ...
  }: {
    # Steam gaming platform configuration
    programs.steam = {
      enable = true;
      package = pkgs.steam.override {
        extraEnv = {
          MANGOHUD = true;
          OBS_VKCAPTURE = true;
          RADV_TEX_ANISO = 16;
        };
        extraLibraries = p:
          with p; [
            atk
          ];
      };
      remotePlay.openFirewall = true;
      extest.enable = true;
    };
    users.users = lib.mapAttrs (n: v: {
      packages = with pkgs; [
        protonup-qt
        mangohud
      ];
    }) (lib.filterAttrs (n: v: lib.elem n includedUsers) config.users);
  };
}
