{self, ...}: {
  flake.homeModules.wallpaper = {lib, ...}: {
    options.wallpaper = lib.mkOption {
      type = lib.types.path;
      default = "${self}/assets//wallpaper.jpg";
      readOnly = true;
      description = "Path to default wallpaper";
    };
  };
}
