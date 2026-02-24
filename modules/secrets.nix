{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.secrets = {...}: {
    imports = [inputs.sops-nix.nixosModules.sops];

    sops = {
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      defaultSopsFile = "${self}/.secrets/default.yaml";
      defaultSopsFormat = "yaml";
      secrets = {
        wifi-turtle-reef = {};
      };
    };
  };
}
