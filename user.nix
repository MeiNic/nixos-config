# =============================================================================
# User Account & Packages
# =============================================================================
{ config, pkgs, ... }:

let
  gwenviewPkg = if builtins.hasAttr "kdeApplications" pkgs && builtins.hasAttr "gwenview" pkgs.kdeApplications then pkgs.kdeApplications.gwenview
                else if builtins.hasAttr "gwenview" pkgs then pkgs.gwenview
                else null;
in

{
  # Define the main user account.
  users.users.nico = {
    isNormalUser = true;
    description  = "nico";
    shell        = pkgs.fish;
    extraGroups  = [ "networkmanager" "wheel" "wireshark" "adbusers" "docker" ];

    packages = builtins.filter (x: x != null) (with pkgs; [
      # ── Communication ───────────────────────────────────────────────────
      thunderbird
      birdtray           # Thunderbird tray icon with unread count
      signal-desktop
      zapzap             # WhatsApp client

      # ── Browsers ────────────────────────────────────────────────────────
      brave
      google-chrome

      # ── Development ─────────────────────────────────────────────────────
      git
      gh                 # GitHub CLI
      act                # Run GitHub Actions locally
      vscode
      go
      jdk
      jdk21
      nodejs
      python3
      python3Packages.pip
      cargo
      rustc
      rustup
      rustfmt
      dart
      flutter
      android-studio
      jetbrains.goland
      jetbrains.idea
      jetbrains.webstorm
      jetbrains.rust-rover
      docker
      docker-compose

      # ── Security & Crypto ───────────────────────────────────────────────
      gnupg
      keepass

      # ── Productivity & Office ───────────────────────────────────────────
      libreoffice-fresh
      drawio
      evince             # PDF viewer
      anki               # Flashcard learning
      gimp
      vlc
      handbrake
      gwenviewPkg
      joplin-desktop     # Note-App
      joplin-cli

      # ── Network & VPN ───────────────────────────────────────────────────
      openconnect
      networkmanager-openconnect

      # ── System & Utilities ──────────────────────────────────────────────
      p7zip
      smartmontools
      hardinfo2
      lm_sensors
      dmidecode
      libpcap
      wireshark
      rclone             # Mount/sync SharePoint, OneDrive-Business, OneDrive

      # ── AI / ML ─────────────────────────────────────────────────────────
      ollama
      open-webui

      # ── Misc ────────────────────────────────────────────────────────────
      ausweisapp
      solaar             # Logitech device manager
      proton-pass
      spotify
      teams-for-linux    # Unofficial Microsoft Teams client

      # ── Zsh plugins (make available to user shell) ───────────────────────
      fish
      zsh-autosuggestions
      zsh-syntax-highlighting
    ]);
  };

  # Zsh must be enabled system-wide so it is a valid login shell.
  programs.zsh.enable = true;
  programs.fish.enable = true;

  # Android Debug Bridge
  programs.adb.enable = true;

  # Wireshark with setcap so non-root users in the wireshark group can capture
  programs.wireshark.enable = true;
}
