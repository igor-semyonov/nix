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
              boot = {
                size = "1024K";
                type = "EF02";
                priority = 1;
              };
              # EFI System Partition
              esp = {
                priority = 2;
                name = "esp";
                size = "${toString (256 * 1024)}K";
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
