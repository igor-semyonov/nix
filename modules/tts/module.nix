{
  self,
  config,
  filterUsers,
  ...
}: {
  flake.nixosModules.programs-tts = {
    pkgs,
    lib,
    config,
    includedUsers,
    ...
  }: let
    cfg = config.igix.tts;

    tts = pkgs.writeShellApplication {
      name = "tts";
      runtimeInputs = with pkgs; [
        stable.wine-staging
        python314
      ];
      text = builtins.readFile ./tts.sh;
    };
    tts-selection = pkgs.writeShellApplication {
      name = "tts-selection";
      runtimeInputs = [tts pkgs.wl-clipboard];
      text = builtins.readFile ./tts-selection.sh;
    };
    tts-screen = pkgs.writeShellApplication {
      name = "tts-screen";
      runtimeInputs = [tts pkgs.kdePackages.spectacle pkgs.tesseract];
      text = builtins.readFile ./tts-screen.sh;
    };
    tts-region = pkgs.writeShellApplication {
      name = "tts-region";
      runtimeInputs = [tts pkgs.kdePackages.spectacle pkgs.tesseract];
      text = builtins.readFile ./tts-region.sh;
    };

    # The ~685 MiB prefix. A fixed-output derivation so it is fetched only when something
    # references it -- see ./_wine-tts.nix for why it is not `inputs.self.lfs = true`.
    wine-tts = pkgs.callPackage ./_wine-tts.nix {};

    # cfg.users holds KEYS from modules/users.nix, not usernames -- `igor-headless` is a
    # key whose account is `igor`. NixOS treats an attr name in users.users as the username
    # unless `name` overrides it, and these entries DO override it, so the account (and
    # therefore the home directory) has to come from `.name`. Resolved here rather than in
    # the builder so a hand-written `igix.tts.users = ["igor-headless"]` behaves the same
    # way as one the builder set.
    #
    # Falls back to the key when an entry has no `name`, which is the plain NixOS
    # behaviour, and skips a key with no user at all rather than generating a unit for a
    # nonexistent account.
    resolved =
      lib.filter (u: u != null)
      (map (
          key: let
            u = config.users.users.${key} or null;
          in
            if u == null
            then null
            else {
              inherit key;
              name = u.name or key;
              home = u.home or "/home/${u.name or key}";
            }
        )
        cfg.users);

    # One oneshot per user rather than a template@.service: the skip condition needs that
    # user's own home path, and a template cannot carry a per-instance ConditionPathExists.
    unitFor = u: {
      name = "tts-wine-prefix-${u.name}";
      value = {
        description = "Unpack the tts wine prefix for ${u.name}";
        wantedBy = ["multi-user.target"];
        # The home directory must exist before unzipping into it. home-manager got this
        # ordering for free by running inside the user's own activation.
        after = ["systemd-user-sessions.service"];
        # The declarative form of `[[ ! -d ... ]]`: systemd skips the unit entirely once the
        # prefix exists, so it is idempotent without scripting the check, and `systemctl
        # status` reports "skipped" rather than the unit silently no-opping.
        unitConfig.ConditionPathExists = "!${u.home}/.wine32-tts";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = u.name;
          # ~685 MiB of zip; the 90 s default is not enough on a slow disk.
          TimeoutStartSec = "10min";
        };
        script = ''
          set -euo pipefail
          ${pkgs.unzip}/bin/unzip -q ${wine-tts}/assets/wine-tts.zip -d ${u.home}
          echo "tts: unpacked the wine prefix into ${u.home}/.wine32-tts"
        '';
      };
    };
  in {
    options.igix.tts = {
      enable = lib.mkEnableOption "Enable TTS" // {default = true;};
      desktop-environment =
        lib.mkEnableOption "Include TTS suited for a desktop environment"
        // {default = true;};
      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = includedUsers;
        defaultText = lib.literalExpression "includedUsers";
        description = ''
          Users to unpack the wine prefix for, as KEYS from modules/users.nix -- the same
          namespace as `includedUsers`, not usernames. `igor-headless` is a key whose
          account is `igor`; the username and home directory are read from that entry.

          Defaults to the host's `includedUsers`, so a host that includes a user gets that
          user's voices without restating the list. Set to `[]` to install the scripts
          without unpacking a prefix for anyone.

          Replaces the old `homeModules.tts` activation script. systemd gives one unit per
          user from one declaration, each with its own skip condition, and a failed unpack
          stays visible in `systemctl status` instead of leaving a partial prefix that the
          next activation's directory check then treats as complete.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages =
        [tts]
        ++ lib.optionals cfg.desktop-environment [
          tts-selection
          tts-screen
          tts-region
        ];

      systemd.services = lib.listToAttrs (map unitFor resolved);
    };
  };

  # Compatibility shim. `homeModules.igix-desktop-linux` imports `tts`, so removing the
  # home module outright would break every desktop host. The unpack now lives in the NixOS
  # module (one unit per user, from `igix.tts.users`), so there is nothing left for this to
  # do -- it exists only so the import keeps resolving.
  #
  # Delete it once `modules/igix.nix` no longer lists `tts` in
  # `homeModules.igix-desktop-linux`, and make sure the host sets `igix.tts.users` (or
  # relies on its default of `includedUsers`) so the prefix is still unpacked.
  flake.homeModules.tts = {};
}
