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
              # EFI System Partition
              ESP = {
                priority = 1;
                name = "ESP";
                start = "1M";
                end = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = ["umask=0077"];
                };
              };
              # BTRFS Root Partition
              root = {
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
                    "/" = {
                      mountpoint = "/mnt/btrfs-pool-root";
                      mountOptions = sharedMountOptions;
                    };
                    "@swap" = {
                      mountpoint = "/swap";
                      # Disko automatically disables CoW (chattr +C) for this file
                      swap.swapfile.size = "3G";
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
                    "@var-log" = {
                      mountpoint = "/var/log";
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
