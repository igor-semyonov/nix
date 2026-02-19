{lib, ...}: {
  config = {
    users = {
      igor = pkgs: {
        nixos = {
          isNormalUser = true;
          description = "Igor Semyonov";
          extraGroups = [
            "networkmanager"
            "wheel"
            "docker"
            "i2c"
          ];
          packages = with pkgs; [
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
            # stable.wl-clipboard
            wl-clipboard
            vivaldi
            vivaldi-ffmpeg-codecs
          ];
        };
      };
    };

    _module.args.usersToNixos = pkgs: users: (
      lib.mapAttrs (n: v: (v pkgs).nixos)
      users
    );
  };

  options = let
    userNixosModule = lib.types.submodule {
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
          type = lib.types.package;
          description = "User's shell";
        };
        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          description = "List of packages to be installed, not using home manager.";
          default = [];
        };
      };
    };
    userModule = lib.types.submodule {
      options = {
        nixos = lib.mkOption {
          description = "Nixos user options";
          # type = lib.types.attrsOf userNixosModule;
          type = lib.types.attrsOf lib.types.anything;
        };
      };
    };
  in {
    users = lib.mkOption {
      default = {};
      description = "Users";
      type = lib.types.attrsOf (lib.types.functionTo userModule);
    };
  };
}
