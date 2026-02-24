{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.secrets = {...}: {
    imports = [inputs.sops-nix.nixosModules.sops];

    sops = {
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      defaultFile = "${self}/.secrets/default.yaml";
      defaultFormat = "yaml";
      secrets = {
        turtle-reef = {};
      };
    };
  };
}
