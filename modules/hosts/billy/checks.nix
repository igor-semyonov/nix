{
  self,
  lib,
  ...
}: {
  perSystem = {...}: {
    checks = let
      # disko's installTest runs the real disko script in a VM, does a full
      # nixos-install, reboots, and asserts the machine comes back. Unlike
      # system.build.vm it does not override fileSystems, so it exercises the
      # partition table, subvolumes, swapfile and bootloader install.
      installTest = modules:
        (self.nixosConfigurations.billy.extendModules {
          modules =
            [
              # test-instrumentation.nix pins this to 7; common-headless to 0.
              {boot.consoleLogLevel = lib.mkForce 7;}
            ]
            ++ modules;
        })
        .config
        .system
        .build
        .installTest;
    in {
      billy-uefi = installTest [{disko.tests.efi = true;}];

      # The harness drives grub.efiSupport from tests.efi, so exercising the
      # BIOS path means forcing it off — this check covers the EF02 half of the
      # hybrid layout, not the config as deployed.
      billy-bios = installTest [
        {
          disko.tests.efi = false;
          boot.loader.grub.efiSupport = lib.mkForce false;
          boot.loader.grub.efiInstallAsRemovable = lib.mkForce false;
        }
      ];
    };
  };
}
