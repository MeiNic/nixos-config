# =============================================================================
# Applications & Everyday Tools (toolchains: development/)
# =============================================================================
{ pkgs, ... }:

let
  inherit (import ../settings.nix) user;
in
{
  users.users.${user}.packages = with pkgs; [
    # ── Communication ───────────────────────────────────────────────────────
    thunderbird
    birdtray           # Thunderbird tray icon with unread count
    signal-desktop
    zapzap

    # ── Browsers ────────────────────────────────────────────────────────────
    brave
    google-chrome

    # ── Security & Crypto ───────────────────────────────────────────────────
    keepassxc

    # ── Productivity & Office ───────────────────────────────────────────────
    libreoffice-fresh
    zotero
    texliveFull        # LaTeX with full package collection
    typst              # Modern markup-based typesetting system
    drawio
    anki               # Flashcard learning
    gimp
    vlc
    handbrake
    # Konsole, Kate, Okular, Gwenview, Ark, Spectacle and System Monitor come
    # with Plasma 6 (services.desktopManager.plasma6) — not listed here.
    kdePackages.kcalc            # calculator
    kdePackages.filelight        # disk usage analyzer
    kdePackages.kfind            # file search
    joplin-desktop     # Note-App
    joplin-cli

    # ── Network & VPN ───────────────────────────────────────────────────────
    openconnect

    # ── System & Utilities ──────────────────────────────────────────────────
    p7zip
    hardinfo2
    lm_sensors
    dmidecode
    rclone             # Mount/sync SharePoint, OneDrive-Business, OneDrive
    hcloud             # Hetzner Cloud CLI - manages Storage Box settings/snapshots/sub-accounts

    # ── CLI Utilities ───────────────────────────────────────────────────────
    ripgrep            # rg: fast grep replacement used by editors/scripts

    # ── Misc ────────────────────────────────────────────────────────────────
    discord
    ausweisapp
    proton-pass
    proton-pass-cli
    spotify
  ];

  # ── Basics for every user ──────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim   # EDITOR (default-apps.nix) and Git's core.editor
    wget
  ];

  programs.firefox.enable = true;

  # ── Flatpak ────────────────────────────────────────────────────────────────
  services.flatpak.enable = true;
}
