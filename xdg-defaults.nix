{ pkgs, lib, ... }:

let
  bindMimes = app: mimes: lib.genAttrs mimes (_: app);
in
{
  # ── Option A: legacy environment variables ──────────────────────────────────
  # Used by terminals, scripts, and programs that don't honour XDG MIME.
  environment.sessionVariables = {
    BROWSER    = "brave";
    TERMINAL   = "konsole";
    EDITOR     = "vim";            # non-graphical editor
    VISUAL     = "code";           # graphical editor (e.g. code / kate)
    PAGER      = "less";
  };

  # ── Option B: XDG MIME default applications ─────────────────────────────────
  # Written to /etc/xdg/mimeapps.list; overridden per-user via
  # ~/.config/mimeapps.list (KDE "Open With…" writes there).
  xdg.mime.defaultApplications = lib.mkMerge [
    (bindMimes "brave-browser.desktop" [
      "text/html" "x-scheme-handler/http" "x-scheme-handler/https"
      "x-scheme-handler/ftp" "x-scheme-handler/about" "x-scheme-handler/unknown"
    ])

    (bindMimes "thunderbird.desktop" [ "x-scheme-handler/mailto" "message/rfc822" ])

    (bindMimes "org.kde.okular.desktop" [ "application/pdf" "application/x-pdf" ])

    (bindMimes "impress.desktop" [
      "application/vnd.ms-powerpoint"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    ])

    (bindMimes "writer.desktop" [
      "application/msword"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    ])

    (bindMimes "calc.desktop" [
      "application/vnd.ms-excel"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    ])

    (bindMimes "org.kde.gwenview.desktop" [
      "image/jpeg" "image/png" "image/gif" "image/webp"
      "image/svg+xml" "image/tiff" "image/bmp"
    ])

    (bindMimes "vlc.desktop" [
      "video/mp4" "video/x-matroska" "video/webm" "video/avi" 
      "video/quicktime" "video/x-msvideo"
      "audio/mpeg" "audio/ogg" "audio/flac" "audio/wav" "audio/aac" "audio/x-m4a"
    ])

    (bindMimes "org.kde.ark.desktop" [
      "application/zip" "application/x-tar" "application/x-compressed-tar"
      "application/x-7z-compressed" "application/x-rar"
    ])

    (bindMimes "code.desktop" [ "text/plain" "text/x-script.python" "application/json" "application/xml" ])

    { "inode/directory" = "org.kde.dolphin.desktop"; }
  ];

  # ── xdg-utils: makes xdg-open / xdg-email / xdg-mime work correctly ────────
  xdg.portal = {
    enable = true;
    # The KDE portal (added by the Plasma module) is preferred; GTK is the fallback
    # for Flatpak apps and anything the KDE portal does not implement.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # Preference order of portal backends.
    config.common.default = [ "kde" "gtk" ];
  };
}
