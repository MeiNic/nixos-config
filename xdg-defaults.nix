# =============================================================================
# Default Applications (XDG MIME, environment variables, xdg-utils)
# =============================================================================
#
# THREE LAYERS – use the right one for each program:
#
#  1. environment.sessionVariables   (Option A)
#     ─────────────────────────────────────────────
#     Shell/session env-vars read by many legacy programs and terminals.
#     Does NOT affect GUI apps launched from the .desktop files.
#
#  2. xdg.mime.defaultApplications   (Option B)  ← the standard approach
#     ─────────────────────────────────────────────
#     Writes /etc/xdg/mimeapps.list.  This is the XDG standard.
#     Most GUI apps (Cinnamon file manager, browsers, …) use this.
#     Values must be .desktop file IDs (basename of the .desktop file).
#
#  3. environment.etc."xdg/mimeapps.list"  (Option C – fallback)
#     ─────────────────────────────────────────────
#     Manual mimeapps.list if you need fine-grained control over
#     entries xdg.mime.defaultApplications does not expose.
#
# Priority:  ~/.config/mimeapps.list  >  /etc/xdg/mimeapps.list
#            (user overrides always win, so Cinnamon's "Open With…"
#             dialog still works as expected)
#
# To find the correct .desktop ID for any program:
#   find /run/current-system/sw/share/applications ~/.local/share/applications \
#        -name '*.desktop' | sort
#
# To inspect what is currently registered for a MIME type:
#   xdg-mime query default text/html
#   xdg-mime query default application/pdf
# =============================================================================
{ pkgs, lib, ... }:

let
  bindMimes = app: mimes: lib.genAttrs mimes (_: app);
in
{
  # ── Option A: legacy environment variables ──────────────────────────────────
  # Used by terminals, scripts, and programs that don't honour XDG MIME.
  environment.sessionVariables = {
    BROWSER    = "brave";          # e.g. brave / google-chrome-stable / firefox
    TERMINAL   = "gnome-terminal"; # e.g. gnome-terminal / xterm / alacritty
    EDITOR     = "vim";            # non-graphical editor
    VISUAL     = "code";           # graphical editor (e.g. code / gedit)
    PAGER      = "less";
  };

  # ── Option B: XDG MIME default applications ─────────────────────────────────
  # Written to /etc/xdg/mimeapps.list; overridden per-user via
  # ~/.config/mimeapps.list (Cinnamon "Open With…" writes there).
  xdg.mime.defaultApplications = lib.mkMerge [
    (bindMimes "brave-browser.desktop" [
      "text/html" "x-scheme-handler/http" "x-scheme-handler/https"
      "x-scheme-handler/ftp" "x-scheme-handler/about" "x-scheme-handler/unknown"
    ])

    (bindMimes "thunderbird.desktop" [ "x-scheme-handler/mailto" "message/rfc822" ])

    (bindMimes "org.gnome.Evince.desktop" [ "application/pdf" "application/x-pdf" ])

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

    (bindMimes "org.gnome.gThumb.desktop" [
      "image/jpeg" "image/png" "image/gif" "image/webp" 
      "image/svg+xml" "image/tiff" "image/bmp"
    ])

    (bindMimes "vlc.desktop" [
      "video/mp4" "video/x-matroska" "video/webm" "video/avi" 
      "video/quicktime" "video/x-msvideo"
      "audio/mpeg" "audio/ogg" "audio/flac" "audio/wav" "audio/aac" "audio/x-m4a"
    ])

    (bindMimes "org.gnome.FileRoller.desktop" [
      "application/zip" "application/x-tar" "application/x-compressed-tar"
      "application/x-7z-compressed" "application/x-rar"
    ])

    (bindMimes "code.desktop" [ "text/plain" "text/x-script.python" "application/json" "application/xml" ])

    { "inode/directory" = "nemo.desktop"; }
  ];

  # ── xdg-utils: makes xdg-open / xdg-email / xdg-mime work correctly ────────
  xdg.portal = {
    enable = true;
    # GTK portal is needed by Flatpak apps and for file-open dialogs.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # Tell the portal which DE is running so it picks the right implementation.
    config.common.default = "gtk";
  };
}
