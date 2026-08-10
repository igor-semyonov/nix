{inputs, ...}: {
  imports = [
    inputs.treefmt-nix.flakeModule
  ];
  perSystem = {...}: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs = {
        alejandra.enable = true; # nix
        stylua.enable = true; # lua
        taplo.enable = true; # toml
        yamlfmt.enable = true;
        prettier.enable = true; # markdown
        shfmt.enable = true;
        # shellcheck.enable = true;
      };
    };
  };
}
