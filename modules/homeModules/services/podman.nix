{...}: {
  flake.homeModules.podman = {...}: {
    # Rootless podman for the user: containers run as this uid rather than root,
    # and no root-equivalent group membership is needed to drive them.
    services.podman.enable = true;
  };
}
