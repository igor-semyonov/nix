{
  self,
  lib,
  ...
}: {
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
            stable.wl-clipboard
            vivaldi
            vivaldi-ffmpeg-codecs
          ];
        };
        home = {
          extraSpecialArgs = {
            userConfig = {
              email = "igor@semyonov.xyz";
              fullName = "Igor Semyonov";
              # gitKey = "C56C6E528F5A18A69B03FC721783BE487E6885DD";
              name = "igor";
            };
          };
          modules = with self.homeModules; [
            common
            qt
            gtk
            xdg
            alacritty
            kitty
            bash
            bat
            vivaldi
            brave
            firefox
            matplotlib
            fastfetch
            gpg
            ssh
            starship
            tmux
            flatpak
            xresources
            rustfmt
            clang-format
            easyeffects
            btop
            fzf

            git
            # zoxide
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
        home = lib.mkOption {
          description = "Home manager to be passed to homeConfiguration";
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
