{lib, ...}: {
  options.namespace-specifier = lib.mkOption {
    type = lib.types.singleLineStr;
    description = "Namespace for nixos and home manager options. It will be accessed as `config.$\{namespace-specifier}`.";
    default = "igix";
  };
}
