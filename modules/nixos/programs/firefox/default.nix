{pkgs, ...}: {
  programs.firefox = {
    enable = true;
    package = pkgs.firefox.overrideAttrs (oldAttrs: {
      disallowedRequisites = [];
    }); # firefox-144 did not build without this
    policies.SecurityDevices.p11-kit-proxy = "${pkgs.p11-kit}/lib/p11-kit-proxy.so";
  };

  environment.etc."pkcs11/modules/opensc-pkcs11".text = ''
    module: ${pkgs.opensc}/lib/opensc-pkcs11.so
  '';
}
