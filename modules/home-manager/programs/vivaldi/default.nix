{
  pkgs,
  lib,
  ...
}: {
  # Ensure Brave browser package installed
  home.packages = with pkgs; [
        vivaldi
        vivaldi-ffmpeg-codecs
  ];

  # Apply XDG configuration only on non-Darwin platforms
  xdg = lib.mkIf (!pkgs.stdenv.isDarwin) {
    mimeApps = {
      defaultApplications = {
        "application/x-extension-htm" = "vivaldi-stable.desktop";
        "application/x-extension-html" = "vivaldi-stable.desktop";
        "application/x-extension-shtml" = "vivaldi-stable.desktop";
        "application/x-extension-xht" = "vivaldi-stable.desktop";
        "application/x-extension-xhtml" = "vivaldi-stable.desktop";
        "application/xhtml+xml" = "vivaldi-stable.desktop";
        "text/html" = "vivaldi-stable.desktop";
        "x-scheme-handler/about" = "vivaldi-stable.desktop";
        "x-scheme-handler/chrome" = ["chromium-browser.desktop"];
        "x-scheme-handler/ftp" = "vivaldi-stable.desktop";
        "x-scheme-handler/http" = "vivaldi-stable.desktop";
        "x-scheme-handler/https" = "vivaldi-stable.desktop";
        "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
        "application/pdf" = "vivaldi-stable.desktop";
      };
    };
  };
}
