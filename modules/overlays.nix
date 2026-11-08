{inputs, ...}: {
  flake.overlays = {
    # When applied, the stable nixpkgs set (declared in the flake inputs) will
    # be accessible through 'pkgs.stable'
    stable-pkgs = final: _prev: {
      stable = import inputs.nixpkgs-stable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    };

    # fastmcp is broken against mcp 2.x; drop once nixpkgs 1a7731090f51
    # ("pdf-mcp: fix mcp compatibility") reaches nixos-unstable.
    pdf-mcp = _final: prev: {
      pdf-mcp = prev.pdf-mcp.override {
        python3Packages = prev.python3Packages.overrideScope (pyFinal: _pyPrev: {
          mcp = pyFinal.mcp_1;
        });
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
  };
}
