{...}: {
  flake.nixosModules.programs-firefox = {
    pkgs,
    lib,
    config,
    ...
  }: {
    # VA-API decode through nvidia-vaapi-driver. Keyed on the nvidia driver
    # actually being in use: LIBVA_DRIVER_NAME=nvidia would break VA-API
    # outright on an AMD or Intel host.
    environment.sessionVariables = lib.mkIf (lib.elem "nvidia" config.services.xserver.videoDrivers) {
      LIBVA_DRIVER_NAME = "nvidia";
      # nvidia-vaapi-driver needs the NVIDIA driver from inside Firefox's RDD
      # process, which the sandbox otherwise denies -- without this, VA-API
      # initialises and then silently falls back to software.
      MOZ_DISABLE_RDD_SANDBOX = "1";
      # Direct NVDEC rather than going via EGL; required since 0.0.10 and
      # what makes it work headless/on Wayland.
      NVD_BACKEND = "direct";
    };

    programs.firefox = {
      enable = true;
      # package = pkgs.firefox.overrideAttrs (oldAttrs: {
      #   disallowedRequisites = [];
      # }); # firefox-144 did not build without this
      policies.SecurityDevices.p11-kit-proxy = "${pkgs.p11-kit}/lib/p11-kit-proxy.so";
    };

    environment.etc."pkcs11/modules/opensc-pkcs11".text = ''
      module: ${pkgs.opensc}/lib/opensc-pkcs11.so
    '';
  };
}
