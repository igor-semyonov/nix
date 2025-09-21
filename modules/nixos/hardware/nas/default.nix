{userConfig, ...}: let
  synology-uri = "//synology.local";
in {
  fileSystems."/mnt/syn" = {
    device = "${synology-uri}/share-1";
    fsType = "cifs";
    options = [
      "credentials=/root/secrets/syn.credentials"
      "uid=${userConfig.name}"
      "gid=${userConfig.name}"
    ];
    noCheck = true;
  };
}
