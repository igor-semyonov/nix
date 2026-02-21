{
  inputs,
  self,
  ...
}: {
  imports = [inputs.home-manager.flakeModules.home-manager];
  flake.homeModules.common = {
    pkgs,
    userConfig,
    ...
  }: {
    # Nixpkgs configuration
    nixpkgs = {
      overlays = [
        self.overlays.stable-pkgs
        inputs.nur.overlays.default
      ];
      config.allowUnfree = true;
    };

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";

    # Home-Manager configuration for the user's home environment
    home = {
      username = "${userConfig.name}";
      homeDirectory =
        if pkgs.pkgs.stdenv.isDarwin
        then "/Users/${userConfig.name}"
        else "/home/${userConfig.name}";
    };

    # Ensure common packages are installed
    home.packages = with pkgs;
      [
        bibata-cursors
        papirus-nord
        anki-bin
        awscli2
        dig
        dust
        eza
        fd
        jq
        # kubectl
        lazydocker
        # nh
        # openconnect
        pipenv
        python3
        ripgrep
        # terraform
      ]
      ++ lib.optionals pkgs.stdenv.isDarwin [
        # colima
        # docker
        # hidden-bar
        # raycast
      ]
      ++ lib.optionals (!pkgs.stdenv.isDarwin) [
        pavucontrol
        tesseract
        unzip
      ];
  };
}
