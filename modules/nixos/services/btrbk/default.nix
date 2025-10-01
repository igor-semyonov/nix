{pkgs, ...}: {
  services.btrbk = {
    instances = {
      local = {
        onCalendar = "*:0/15";
        settings = {
          timestamp_format = "long";
          preserve_day_of_week = "monday";
          preserve_hour_of_day = "0";
          volume = {
            "/mnt/btrfs-pool" = {
              snapshot_preserve_min = "6h";
              snapshot_preserve = "8h 7d 3w";
              snapshot_create = "always";
              snapshot_dir = "btrbk-snapshots";
              subvolume = {
                "@" = {};
                "@home" = {};
              };
            };
          };
        };
      };
    };
  };
}
