{
  self,
  lib,
  ...
}: {
  config = {
    users = {
      igor = pkgs: rec {
        name = "igor";
        nixos = {
          name = name;
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
          modules = with self.homeModules; [
            {
              userConfig = {
                name = name;
                email = "igor@semyonov.xyz";
                fullName = "Igor Semyonov";
                gitKey = "C2E5A3AAF5F754F0";
              };
            }
            common
            kde
            hyprland

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
      igor-work = pkgs: rec {
        name = "igor";
        nixos = {
          name = name;
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
          modules = with self.homeModules; [
            {
              userConfig = {
                name = name;
                email = "igor.semyonov.civ@army.mil";
                fullName = "Igor Semyonov";
                gitKey = "021B681D5415F152";
              };
            }
            common
            kde
            # hyprland

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
      igor-leto = pkgs: rec {
        name = "igor";
        nixos = {
          name = name;
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
          modules = with self.homeModules; [
            {
              userConfig = {
                name = name;
                email = "igor.semyonov.civ@army.mil";
                fullName = "Igor Semyonov";
                gitKey = "021B681D5415F152";
              };
              home.stateVersion = "25.11";
            }
            common
            kde
            # hyprland

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
      # igor-work = let
      #   extraSpecialArgs =
      #     lib.zipAttrsWith (n: v:
      #       if n == "userConfig"
      #       then (lib.head v) // (lib.last v)
      #       else lib.head v)
      #     [
      #       igor.home.extraSpecialArgs.userConfig
      #       {
      #         email = "igor.semyonov.civ@army.mil";
      #         gitKey = "021B681D5415F152";
      #       }
      #     ];
      #   home = lib.zipAttrsWith (n: v:
      #     if n == "extraSpecialArgs"
      #     then lib.last v
      #     else lib.head v) [igor.home {inherit extraSpecialArgs;}];
      # in {
      #   inherit (igor) nixos;
      #   inherit home;
      # };
    };

    _module.args.usersToNixos = pkgs: users: (
      lib.mapAttrs (n: v: (v pkgs).nixos)
      users
    );

    flake.homeModules.users = {
      options.userConfig = {
        name = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "Username";
        };
        fullName = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "Long prettyprintable name";
        };
        email = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "User email address";
        };
        gitKey = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "GPG key id for git signing.";
        };
      };
    };
  };

  options = let
    # userNixosModule = lib.types.submodule {
    #   options = {
    #     description = lib.mkOption {
    #       type = lib.types.singleLineStr;
    #       description = "Description, often times full nname";
    #       default = "";
    #     };
    #     extraGroups = lib.mkOption {
    #       type = lib.types.listOf lib.types.singleLineStr;
    #       description = "Groups to which the user will be added";
    #       default = [];
    #     };
    #     isNormalUser = lib.mkOption {
    #       type = lib.types.bool;
    #       description = "Is normal user";
    #       default = true;
    #     };
    #     shell = lib.mkOption {
    #       type = lib.types.package;
    #       description = "User's shell";
    #     };
    #     packages = lib.mkOption {
    #       type = lib.types.listOf lib.types.package;
    #       description = "List of packages to be installed, not using home manager.";
    #       default = [];
    #     };
    #   };
    # };
    userModule = lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.singleLineStr ;
          description = "The username for this user";
        };
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
