# Imports the shared host plumbing into this flake, and re-exports it so
# consumers (e.g. the work config) get the same builders without duplicating
# them. See ../_lib/hosts.nix.
{...}: {
  imports = [../_lib/hosts.nix];
  flake.flakeModules.hosts = ../_lib/hosts.nix;
}
