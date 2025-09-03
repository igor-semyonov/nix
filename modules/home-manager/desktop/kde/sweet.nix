{
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "sweet-kde";
  version = "1.0";
  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Sweet-kde";
    rev = "master";
    hash = "sha256-rGDXRZiIddn2t8mVQNdwpe/loe+9IIe++E7BGu42AKA=";
  };

  phases = ["installPhase"];

  installPhase =
    /*
    bash
    */
    ''
      mkdir -v build
      cd build || exit
      unpackPhase --verbose
      out="$out"/Sweet
      mkdir -vp "$out"
      cp  -vr source/* "$out"/.
    '';
}
