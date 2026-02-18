{pkgs, ...}: {
  home.file.".config/rustfmt/rustfmt.toml".source = ./rustfmt.toml;
}
