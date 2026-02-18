{lib, ...}: {
  options = let
    userModule = lib.types.submodule {
      options = {
        description = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "Description, often times full nname";
          default = "";
        };
        extraGroups = lib.mkOption {
          type = lib.types.listOf lib.types.singleLineStr;
          description = "Groups to which the user will be added";
          default = [];
        };
        isNormalUser = lib.mkOption {
          type = lib.types.bool;
          description = "Is normal user";
          default = true;
        };
        shell = lib.mkOption {
          type = lib.types.functionTo lib.types.package;
          description = "User's shell";
          default = pkgs: pkgs.bash;
        };
        packages = lib.mkOption {
          type = lib.types.functionTo lib.types.listOf lib.types.package;
          description = "List of packages to be installed, not using home manager.";
          default = pkgs: [];
        };
      };
    };
  in {
    users = lib.mkOption {
      default = {};
      description = "Users";
      type = lib.types.attrsOf userModule;
    };
  };

  config = {
    users = {
      igor = {
        description = "Igor Semyonov";
        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
          "i2c"
        ];
        packages = pkgs:
          with pkgs; [
            gh
            pass
            dropbox
            dropbox-cli
            cryptomator
            zoxide
            python313
            unzip
            starship
            ripgrep
            stable.wl-clipboard
            vivaldi
            vivaldi-ffmpeg-codecs
          ];
      };
      john = {
        description = "Igor Semyonov";
        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
          "i2c"
        ];
      };
    };

    _module.args.usersToNixos = users: pkgs: (
      lib.mapAttrs (n: v: {
        inherit (v) description isNormalUser extraGroups;
        shell = v.shell pkgs;
        packages = v.packages pkgs;
      })
      users
    );
  };
}
