{...}: {
  flake.nixosModules.programs-open-audible = {
    pkgs,
    lib,
    config,
    ...
  }: let
    cfg = config.igix.openaudible;

    # Packaged from the .deb rather than the AppImage: the AppImage's only
    # nix-native wrapper (appimageTools.wrapType2) exposes nothing but
    # extraPkgs, and SWT's TLS needs GIO_EXTRA_MODULES set — an env var, not a
    # package. The .deb unpacks to a plain tree that autoPatchelfHook can fix
    # and makeWrapper can parameterise.
    openaudible = pkgs.stdenv.mkDerivation (finalAttrs: {
      pname = "openaudible";
      version = "5.0.3";

      src = pkgs.fetchurl {
        url = "https://github.com/openaudible/openaudible/releases/download/v${finalAttrs.version}/OpenAudible_${finalAttrs.version}_x86_64.deb";
        hash = "sha256-Q2+Y+yJLjsVcv08t5FNhbTvm/un39IxCJw4+h+1YkDM=";
      };

      nativeBuildInputs = with pkgs; [
        dpkg
        autoPatchelfHook
        makeWrapper
      ];

      # Shared by buildInputs and the wrapper's LD_LIBRARY_PATH. SWT unpacks its
      # native .so files into ~/.swt at runtime, where they have no RPATH for
      # autoPatchelf to have fixed, so every one of these has to be reachable
      # through the loader path too — keeping one list stops the two drifting.
      runtimeLibs = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        glib
        gtk3
        cairo
        pango
        gdk-pixbuf
        atk
        fontconfig
        freetype
        alsa-lib
        libGL
        webkitgtk_4_1
        xorg.libX11
        xorg.libXext
        xorg.libXi
        xorg.libXrender
        xorg.libXtst
      ];

      buildInputs = finalAttrs.runtimeLibs;

      # The bundled JRE's libraries resolve libjvm.so relative to themselves at
      # runtime, so autoPatchelf cannot and need not find it.
      autoPatchelfIgnoreMissingDeps = ["libjvm.so"];

      unpackPhase = ''
        runHook preUnpack
        dpkg-deb -x "$src" .
        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/share/openaudible"
        cp -r opt/OpenAudible/. "$out/share/openaudible/"

        install -Dm644 opt/OpenAudible/.install4j/OpenAudible.png \
          "$out/share/icons/hicolor/256x256/apps/org.openaudible.OpenAudible.png"
        install -Dm644 opt/OpenAudible/share/applications/org.openaudible.OpenAudible.desktop \
          "$out/share/applications/org.openaudible.OpenAudible.desktop"

        runHook postInstall
      '';

      postFixup = ''
        makeWrapper "$out/share/openaudible/OpenAudible" "$out/bin/OpenAudible" \
          --set INSTALL4J_JAVA_HOME_OVERRIDE "$out/share/openaudible/jre" \
          --set GIO_EXTRA_MODULES "${pkgs.glib-networking}/lib/gio/modules" \
          --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.runtimeLibs}"
      '';

      meta = {
        description = "Download and manage Audible audiobooks";
        homepage = "https://openaudible.org";
        downloadPage = "https://github.com/openaudible/openaudible/releases";
        license = lib.licenses.unfree;
        sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
        platforms = ["x86_64-linux"];
        mainProgram = "OpenAudible";
      };
    });
  in {
    options.igix.openaudible.enable =
      lib.mkEnableOption "OpenAudible, packaged from the upstream .deb";

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [openaudible];
    };
  };
}
