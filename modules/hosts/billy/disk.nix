{inputs, ...}: {
  flake.nixosModules.billy-disks = {
    imports = [inputs.disko.nixosModules.disko];
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          # NOTE: Hetzner Cloud VMs (CX/CPX) usually use /dev/sda
          # Hetzner ARM VMs (CAX) and Dedicated Servers often use /dev/nvme0n1
          device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-0";
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
                    "@var" = {
                      mountpoint = "/var";
                      mountOptions = sharedMountOptions;
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = sharedMountOptions;
                    };
                    "/" = {
                      mountpoint = "/mnt/btrfs-pool";
                      mountOptions = sharedMountOptions;
                    };
                    "@swap" = {
                      mountpoint = "/swap";
                      # Disko automatically disables CoW (chattr +C) for this file
                      swap.swapfile.size = "2G";
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
