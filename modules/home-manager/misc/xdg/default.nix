{pkgs, ...}: {
  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      associations.added = {
        "audio/mpeg" = ["mpv.desktop"];
        "image/jpeg" = ["org.kde.gwenview.desktop"];
        "image/jpg" = ["org.kde.gwenview.desktop"];
        "image/png" = ["org.kde.gwenview.desktop"];
        "video/mp3" = ["mpv.desktop"];
        "video/mp4" = ["mpv.desktop"];
        "video/quicktime" = ["mpv.desktop"];
        "video/webm" = ["mpv.desktop"];
      };
      defaultApplications = let
        text = "nvim.desktop";
      in {
        "application/json" = text;
        "application/toml" = text;
        "application/x-gnome-saved-search" = ["org.gnome.Nautilus.desktop"];
        "audio/*" = "mpv.desktop";
        "image/*" = "org.kde.gwenview.desktop";
        "text/*" = text;
        "video/*" = "mpv.desktop";
      };
    };
    userDirs = {
      enable = true;
      createDirectories = true;
    };
    portal = {
      # extraPortals = [
      #   pkgs.kdePackages.xdg-desktop-portal-kde
      #   pkgs.xdg-desktop-portal-gtk # Often needed as a fallback
      # ];
      configPackages = with pkgs; [
        kdePackages.xdg-desktop-portal-kde
      ];
      config = {
        common = {
          # This tells xdg-desktop-portal to use the KDE backend for file picking
          "org.freedesktop.impl.portal.FileChooser" = ["kde"];
          # Sets the default for everything else to KDE, with GTK as a fallback
          default = ["kde" "gtk"];
        };
      };
    };
  };
}
