{
  fetchurl,
  fakeHash,
  appimageTools,
  lib,
  ...
}: let
  pname = "open-audible";
  version = "4.6.3";
  src = fetchurl {
    url = "https://github.com/openaudible/openaudible/releases/download/v${version}/OpenAudible_${version}_x86_64.AppImage";
    hash = fakeHash;
  };
  appimageContents = appimageTools.extractType1 {inherit pname src;};
in
  appimageTools.wrapType2 rec {
    inherit pname version src;
    extraInstallCommands = ''
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${meta.mainProgram}'
    '';
    meta = {
      description = "Download and manage audiobooks";
      homepage = "https://github.com/openaudible/openaudible";
      downloadPage = "https://github.com/openaudible/openaudible/releases";
      license = lib.licensee.asl20;
      # sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      maintainers = with lib.maintainers; [onny];
      platforms = ["x86_64-linux"];
    };
  }
