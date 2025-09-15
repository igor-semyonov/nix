{inputs, ...}: {
  # When applied, the stable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.stable'
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  # vivaldi = final: prev: {
  #   vivaldi = prev.vivaldi.override {
  #     commandLineArgs = [
  #       "--ignore-gpu-blocklist"
  #       # "--enable-accelerated-video-encode"
  #       # "--enable-accelerated-video-decode"
  #       "--enable-features=UseOzonePlatform,VaapiVideoDecoder"
  #       "--ozone-platform=wayland"
  #       "--use-gl=egl"
  #     ];
  #   };
  # };
}
