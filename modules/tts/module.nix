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
      runtimeInputs =
        [
          cfg.wine-package
          pkgs.python314
        ]
        ++ lib.optional cfg.headless pkgs.xvfb-run;
      # Under `headless`, run the whole thing inside a throwaway X server.
      #
      # balcon needs a display even with `-i`. Without one, wine logs
      # "nodrv_CreateWindow ... no driver could be loaded", never opens an audio device,
      # and STILL EXITS 0 -- the script pipes wine to `&>/dev/null`, so a silent failure is
      # indistinguishable from success. Established by controlled comparison on hardware
      # (same session, same user, only the display differing): no `Stream/Output/Audio`
      # node ever appears without Xvfb, and `balcon.exe` appears as a stream with it.
      #
      # This is the same reason a fresh prefix pops a wine window on first run after a wine
      # update: it wants somewhere to put it, and a TTY session has nowhere.
      #
      # `-a` picks a free display number, so concurrent invocations do not collide.
      text =
        if cfg.headless
        then ''
          exec xvfb-run -a ${pkgs.bash}/bin/bash ${pkgs.writeText "tts-inner.sh" (builtins.readFile ./tts.sh)} "$@"
        ''
        else builtins.readFile ./tts.sh;
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
      headless = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          This host has no graphical session: an SSH login, a bare TTY, or a systemd unit.

          Two consequences, which is why this is one option rather than two:

          1. Wrap `tts` in `xvfb-run`. balcon needs a display even in `-i` (non-interactive)
             mode. Without one, wine logs `nodrv_CreateWindow ... no driver could be loaded`,
             never opens an audio device, and STILL EXITS 0 -- tts.sh sends wine's output to
             `&>/dev/null`, so the failure is completely silent: `tts` succeeds and nothing
             plays.

             Verified by controlled comparison on hardware (same host, user and fresh
             pipewire; only the display differing): no `Stream/Output/Audio` node ever
             appears without Xvfb, `balcon.exe` shows up as a stream with it, and the mic
             envelope goes from a flat -19 dBFS noise floor to a clear -12.7 dBFS utterance.

             Related: this is why a wine window sometimes appears on the first run after a
             wine update. Wine wants somewhere to put it, and with no display that step fails
             and takes the audio path down with it.

          2. Omit tts-selection, tts-screen and tts-region, which need wl-clipboard,
             spectacle and tesseract to read a Wayland session that does not exist here.

          Costs xvfb-run plus a small X server in the closure, and adds no measurable startup
          time -- wine itself takes ~45 s before the first sample either way.
        '';
      };
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
      wine-package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.stable.wine-staging or pkgs.wine-staging;
        defaultText = lib.literalExpression "pkgs.stable.wine-staging or pkgs.wine-staging";
        description = ''
          The wine build the voices run under. 32-bit wine, hence x86_64 only.

          `pkgs.stable` is an attribute THIS flake's `overlays.stable-pkgs` adds; a consumer
          importing this module into their own nixpkgs has no such attribute, so referencing
          it unconditionally made the module fail to evaluate outside this flake with
          `undefined variable 'stable'`. Hence the `or` fallback, and hence an option: a
          consumer whose unstable wine is broken can point this at their own pin instead of
          being told to add an overlay.

          Preferring stable is deliberate -- wine-staging regressions on unstable have
          broken the voices before, and the prefix is prebuilt against a known-good wine.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages =
        [tts]
        ++ lib.optionals (!cfg.headless) [
          tts-selection
          tts-screen
          tts-region
        ];

      systemd.services = lib.listToAttrs (map unitFor resolved);
    };
  };
}
