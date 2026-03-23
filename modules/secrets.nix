{inputs, ...}: {
  flake.nixosModules.secrets = {pkgs, ...}: {
    imports = [inputs.sops-nix.nixosModules.sops];
    environment.systemPackages = with pkgs; [sops ssh-to-age];

    sops = {
      gnupg.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

      # use the .secrets directory
      # defaultSopsFile = "${self}/.secrets/default.yaml";
      # or use an external input to this flake
      defaultSopsFile = "${inputs.sops-secrets}/default.yaml";

      defaultSopsFormat = "yaml";
      secrets = {
        wifi-turtle-reef = {};
      };
    };
  };
}
