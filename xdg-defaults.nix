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
{ pkgs, ... }:

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
  xdg.mime.defaultApplications = {

    # ── Web ──────────────────────────────────────────────────────────────────
    "text/html"                = "brave-browser.desktop";
    "x-scheme-handler/http"    = "brave-browser.desktop";
    "x-scheme-handler/https"   = "brave-browser.desktop";
    "x-scheme-handler/ftp"     = "brave-browser.desktop";
    "x-scheme-handler/about"   = "brave-browser.desktop";
    "x-scheme-handler/unknown" = "brave-browser.desktop";

    # ── E-Mail ───────────────────────────────────────────────────────────────
    "x-scheme-handler/mailto"  = "thunderbird.desktop";
    "message/rfc822"           = "thunderbird.desktop";

    # ── PDF & Documents ──────────────────────────────────────────────────────
    "application/pdf"                  = "org.gnome.Evince.desktop";
    "application/x-pdf"                = "org.gnome.Evince.desktop";
    "application/vnd.ms-powerpoint"    = "impress.desktop";          # LibreOffice Impress
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
                                       = "impress.desktop";
    "application/msword"               = "writer.desktop";           # LibreOffice Writer
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                                       = "writer.desktop";
    "application/vnd.ms-excel"         = "calc.desktop";             # LibreOffice Calc
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                                       = "calc.desktop";

    # ── Images ───────────────────────────────────────────────────────────────
    "image/jpeg"      = "org.gnome.gThumb.desktop";  # or: eog.desktop / gwenview.desktop / gimp.desktop
    "image/png"       = "org.gnome.gThumb.desktop";
    "image/gif"       = "org.gnome.gThumb.desktop";
    "image/webp"      = "org.gnome.gThumb.desktop";
    "image/svg+xml"   = "org.gnome.gThumb.desktop";
    "image/tiff"      = "org.gnome.gThumb.desktop";
    "image/bmp"       = "org.gnome.gThumb.desktop";

    # ── Video ────────────────────────────────────────────────────────────────
    "video/mp4"       = "vlc.desktop";
    "video/x-matroska"= "vlc.desktop";
    "video/webm"      = "vlc.desktop";
    "video/avi"       = "vlc.desktop";
    "video/quicktime" = "vlc.desktop";
    "video/x-msvideo" = "vlc.desktop";

    # ── Audio ────────────────────────────────────────────────────────────────
    "audio/mpeg"      = "vlc.desktop";
    "audio/ogg"       = "vlc.desktop";
    "audio/flac"      = "vlc.desktop";
    "audio/wav"       = "vlc.desktop";
    "audio/aac"       = "vlc.desktop";
    "audio/x-m4a"     = "vlc.desktop";

    # ── Archives ─────────────────────────────────────────────────────────────
    # Cinnamon's file manager (Nemo) handles these natively via file-roller.
    "application/zip"             = "org.gnome.FileRoller.desktop";
    "application/x-tar"           = "org.gnome.FileRoller.desktop";
    "application/x-compressed-tar"= "org.gnome.FileRoller.desktop";
    "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
    "application/x-rar"           = "org.gnome.FileRoller.desktop";

    # ── Text / Code ──────────────────────────────────────────────────────────
    "text/plain"      = "code.desktop";      # VS Code; or: gedit.desktop / vim.desktop
    "text/x-script.python" = "code.desktop";
    "application/json"     = "code.desktop";
    "application/xml"      = "code.desktop";

    # ── File manager ─────────────────────────────────────────────────────────
    "inode/directory"  = "nemo.desktop";     # Cinnamon's Nemo file manager
  };

  # ── xdg-utils: makes xdg-open / xdg-email / xdg-mime work correctly ────────
  xdg.portal = {
    enable = true;
    # GTK portal is needed by Flatpak apps and for file-open dialogs.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # Tell the portal which DE is running so it picks the right implementation.
    config.common.default = "gtk";
  };
}
