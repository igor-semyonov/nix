{...}: {
  services.easyeffects = {
    enable = true;
    extraPresets = let
      npr-voice = import ./npr-voice.nix;
    in {
      my-preset = npr-voice;
    };
    preset = "my-preset";
  };
}
