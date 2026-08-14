{inputs, ...}: {
  flake.nixosModules.billy-disks = {
    imports = [inputs.disko.nixosModules.disko];
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = "/dev/vda";
          content = {
            type = "gpt";
            partitions = {
              # BIOS boot partition, holds GRUB's core.img on GPT. Paired with
              # the ESP below so one config boots both BIOS and UEFI instances:
              # grub installs i386-pc here and x86_64-efi into the ESP on the
              # same run. 1 MiB would do with /boot on vfat; 2 is free headroom.
              boot = {
                size = "2048K";
                type = "EF02";
                priority = 1;
              };
              # EFI System Partition, also carries the kernels. It is a
              # different filesystem from /nix/store, so grub forces
              # copyKernels regardless of the option, at ~45 MiB per distinct
              # kernel+initrd set. 1 GiB covers configurationLimit = 10.
              esp = {
                priority = 2;
                name = "esp";
                size = "${toString (1024 * 1024)}K";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  extraArgs = ["-F" "32"];
                  mountpoint = "/boot";
                  mountOptions = ["umask=0077"];
                };
              };
              # BTRFS Root Partition
              root = {
                name = "root";
                size = "100%";
                content = {
                  type = "btrfs";
                  # Overwrite existing partitions if repurposing a drive
                  extraArgs = ["-f"];
                  subvolumes = let
                    sharedMountOptions = [
                      "compress-force=zstd:3"
                      "noatime"
                      "noautodefrag"
                      "commit=45"
                    ];
                  in {
                    "@" = {
                      mountpoint = "/";
                      mountOptions = sharedMountOptions;
                    };
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = sharedMountOptions;
                    };
                    "@root" = {
                      mountpoint = "/root";
                      mountOptions = sharedMountOptions;
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = sharedMountOptions;
                    };
                    "@var-log" = {
                      mountpoint = "/var/log";
                      mountOptions = sharedMountOptions;
                    };
                    "/" = {
                      mountpoint = "/mnt/btrfs-pool-root";
                      mountOptions = sharedMountOptions;
                    };
                    "@swap" = {
                      mountpoint = "/swap";
                      swap.swapfile.size = "8G";
                    };
                  };
                };
              };
            };
          };
        };
        data = {
          type = "disk";
          device = "/dev/vdb";
          content = {
            type = "gpt";
            partitions = {
              data = {
                name = "data";
                size = "100%";
                content = {
                  type = "btrfs";
                  # Overwrite existing partitions if repurposing a drive
                  extraArgs = ["-f"];
                  subvolumes = let
                    sharedMountOptions = [
                      "compress-force=zstd:3"
                      "noatime"
                      "noautodefrag"
                      "commit=45"
                    ];
                  in {
                    "@var-lib" = {
                      mountpoint = "/var/lib";
                      mountOptions = sharedMountOptions;
                    };
                    "/" = {
                      mountpoint = "/mnt/btrfs-pool-data";
                      mountOptions = sharedMountOptions;
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
