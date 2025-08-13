{pkgs, ...}: {
  programs.firefox = {
    enable = true;
    policies.SecurityDevices.p11-kit-proxy = "${pkgs.p11-kit}/lib/p11-kit-proxy.so";
  };

  environment.etc."pkcs11/modules/opensc-pkcs11".text = ''
    module: ${pkgs.opensc}/lib/opensc-pkcs11.so
  '';
}
