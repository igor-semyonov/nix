{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.secrets = {pkgs, ...}: {
    imports = [inputs.sops-nix.nixosModules.sops];
    environment.systemPackages = with pkgs; [sops ssh-to-age];

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
