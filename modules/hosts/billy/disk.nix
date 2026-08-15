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
              # Paired with the ESP so one config boots BIOS and UEFI: grub
              # installs i386-pc here and x86_64-efi into the ESP on the same run.
              boot = {
                size = "2048K";
                type = "EF02";
                priority = 1;
              };
              # Also carries the kernels: a different filesystem from /nix/store
              # forces copyKernels regardless of the option, ~45 MiB per set.
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
                      "compress=zstd:3"
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
                    # Transient; separate so btrbk snapshots of @ stay clean.
                    "@tmp" = {
                      mountpoint = "/tmp";
                      mountOptions = sharedMountOptions;
                    };
                    "@var-tmp" = {
                      mountpoint = "/var/tmp";
                      mountOptions = sharedMountOptions;
                    };
                    "@var-cache" = {
                      mountpoint = "/var/cache";
                      mountOptions = sharedMountOptions;
                    };
                    "/" = {
                      mountpoint = "/mnt/btrfs-pool-root";
                      mountOptions = sharedMountOptions;
                    };
                    # No mountOptions: btrfs swapfiles reject compression.
                    "@swap" = {
                      mountpoint = "/swap";
                      swap.swapfile.size = "${toString (5 * 1024 * 1024)}K";
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
                    # compress, not compress-force: most of /var/lib is
                    # incompressible (encrypted vault blobs, mail attachments).
                    sharedMountOptions = [
                      "compress=zstd:3"
                      "noatime"
                      "noautodefrag"
                      "commit=45"
                    ];
                  in {
                    "@var-lib" = {
                      mountpoint = "/var/lib";
                      mountOptions = sharedMountOptions;
                    };
                    # Own subvolumes so each service can be snapshotted and
                    # rolled back independently, and so nodatacow can be set
                    # later without migrating live data.
                    "@stalwart" = {
                      mountpoint = "/var/lib/stalwart";
                      mountOptions = sharedMountOptions;
                    };
                    "@vaultwarden" = {
                      mountpoint = "/var/lib/vaultwarden";
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
