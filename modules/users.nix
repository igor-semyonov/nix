{inputs, ...}: let
  lib = inputs.nixpkgs.lib;
  types = lib.types;
in {
  options = let
    userModule = types.submodule {
      options = {
      };
    };
  in {
  };
}
