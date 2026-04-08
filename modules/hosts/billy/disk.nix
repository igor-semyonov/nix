{inputs, ...}: {
  flake.nixosModules.billy-disks = {
    imports = [inputs.disko.nixosModules.disko];
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          # NOTE: Hetzner Cloud VMs (CX/CPX) usually use /dev/sda
          # Hetzner ARM VMs (CAX) and Dedicated Servers often use /dev/nvme0n1
          device = "/dev/sda";
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
                  mountpoint = "/boot/efi";
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
                  subvolumes = {
                    # Root subvolume
                    "@" = {
                      mountpoint = "/";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    # Home subvolume
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    # Nix store subvolume
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    # Swap subvolume
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
