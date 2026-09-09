{...}: {
  flake.nixosModules.podman = {lib, ...}: {
    virtualisation.podman = {
      # mkDefault so hosts can opt out without mkForce.
      enable = lib.mkDefault true;
      # `docker` as an alias for `podman`. Deliberately *not* dockerSocket —
      # that exposes /run/docker.sock to the `podman` group, which is
      # root-equivalent in exactly the way the `docker` group was.
      dockerCompat = lib.mkDefault true;
      autoPrune.enable = lib.mkDefault true;
    };
  };
}
