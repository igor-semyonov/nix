{
  self,
  lib,
  ...
}: {
  config = {
    users = {
      igor = let
        name = "igor";
        fullName = "igor Semyonov";
        email = hostname:
          if hostname == "tavore"
          then "igor.semyonov.civ@army.mil"
          else "igor@semyonov.xyz";
        gitKeys = {
          boxy = "C2E5A3AAF5F754F0";
          tavore = "021B681D5415F152";
          leto = "EA59146CF56DCC27";
        };
        homeStateVersion = {
          boxy = "25.05";
          tavore = "25.05";
          leto = "25.11";
        };
      in
        pkgs: hostname: {
          nixos = {
            name = name;
            isNormalUser = true;
            description = fullName;
            extraGroups = [
              "networkmanager"
              "wheel"
              "docker"
              "i2c"
              "dialout"
            ];
            packages = with pkgs; [
              nmap
              pciutils
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
              wl-clipboard
              vivaldi
              vivaldi-ffmpeg-codecs
            ];
          };
          home = {
            modules = with self.homeModules;
              [
                ({pkgs, ...}: {
                  userConfig = {
                    name = name;
                    email = email hostname;
                    fullName = fullName;
                    gitKey = gitKeys.${hostname};
                  };
                  home.stateVersion = homeStateVersion.${hostname};
                  home.packages = [pkgs.antigravity-cli];
                })
              ]
              ++ lib.optionals pkgs.stdenv.isLinux [
                igix-desktop-linux
                {
                  igix = {
                    mcp = {
                      enable = true;
                      playwright.enable = true;
                      gh.useGhCli = true;
                    };
                    flatpak.packages = [
                      # "org.libreoffice.LibreOffice" # switched to nixpkgs version for better qt support
                      "com.obsproject.Studio"
                      # "org.prismlauncher.PrismLauncher"
                      "com.discordapp.Discord"
                    ];
                  };
                }
              ]
              ++ lib.optionals pkgs.stdenv.isDarwin [igix-desktop-mac];
          };
        };
      igor-headless = let
        name = "igor";
        fullName = "igor Semyonov";
        email = "igor@semyonov.xyz";
        gitKeys = {
          billy = "placeholder";
        };
        homeStateVersion = {
          billy = "26.11";
        };
      in
        pkgs: hostname: {
          nixos = {
            name = name;
            isNormalUser = true;
            description = fullName;
            openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH5gmBdZsP86dXIL7P/Wb+mBtXO/1xqqKMNKKqLr8SJZ igor@boxy"];
            extraGroups = [
              "networkmanager"
              "wheel"
              "docker"
              "i2c"
              "dialout"
            ];
            packages = with pkgs; [
              just
              zoxide
              unzip
              starship
              ripgrep
            ];
          };
          home = {
            modules = with self.homeModules; [
              {
                userConfig = {
                  name = name;
                  email = email;
                  fullName = fullName;
                  gitKey = gitKeys.${hostname};
                };
                home.stateVersion = homeStateVersion.${hostname};
              }
              common-headless

              bash
              bat
              gpg
              ssh
              starship
              tmux
              btop
              fzf
              git
              # zoxide
            ];
          };
        };
      kaladin = let
        name = "kaladin";
        fullName = "Kaladin (the red From) Semyonov";
        homeStateVersion = {
          leto = "25.11";
        };
      in
        pkgs: hostname: {
          nixos = {
            name = name;
            isNormalUser = true;
            description = fullName;
            extraGroups = [
              "networkmanager"
            ];
            packages = with pkgs; [
              pass
              dropbox
              python313
              unzip
              ripgrep
              wl-clipboard
              vivaldi
              vivaldi-ffmpeg-codecs
            ];
          };
          home = {
            modules = with self.homeModules;
              [
                {
                  userConfig = {
                    name = name;
                    fullName = fullName;
                  };
                  home.stateVersion = homeStateVersion.${hostname};
                }
                common

                alacritty
                bash
                starship
                bat
                fastfetch
              ]
              ++ lib.optionals pkgs.stdenv.isLinux [
                # kde
                # hyprland

                # qt
                # gtk
                # xdg
                # easyeffects
                flatpak
                {
                  igix.flatpak.packages = [
                    "org.kde.gcompris"
                    "org.kde.ktuberling"
                    "org.tuxpaint.Tuxpaint"
                    "net.supertuxkart.SuperTuxKart"
                    "org.supertuxproject.SuperTux"
                    "party.supertux.supertuxparty"
                    "io.github.retux_game.retux"
                    "com.tux4kids.tuxmath"
                    "com.tux4kids.tuxtype"
                  ];
                  services.flatpak.uninstallUnmanaged = lib.mkForce false;
                }
              ];
          };
        };
    };

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
}
