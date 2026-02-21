{...}: {
  flake.homeModules.clang-format = {pkgs, ...}: {
    home.file.".clang-format".source = ./clang-format;
  };
}
