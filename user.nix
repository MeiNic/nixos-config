# =============================================================================
# User Account & Packages
# =============================================================================
{ pkgs, ... }:

{
  # Define the main user account.
  users.users.nico = {
    isNormalUser = true;
    description  = "nico";
    initialHashedPassword = "$6$dWIUHsKbON.yT1am$tQOmnIRxNZu6xEMRT2R5QdsCUG8Eo2kcRZVjyG.vdoKNjVz9wJFa3GCyWUPZFxswsQ0V9p1rV1as/4yalBMa8/";
    shell        = pkgs.fish;
    extraGroups  = [ "networkmanager" "wheel" "wireshark" "adbusers" "docker" "vboxusers" ];

    packages = with pkgs; [
      # ── Communication ───────────────────────────────────────────────────
      thunderbird
      birdtray           # Thunderbird tray icon with unread count
      signal-desktop
      zapzap             # WhatsApp client

      # ── Browsers ────────────────────────────────────────────────────────
      brave
      google-chrome

      # ── Development ─────────────────────────────────────────────────────
      gh                 # GitHub CLI
      act                # Run GitHub Actions locally
      vscode
      go
      jdk21
      nodejs
      python3
      rustup
      gcc
      dart
      flutter
      android-studio
      android-tools
      jetbrains.goland
      jetbrains.idea
      jetbrains.webstorm
      jetbrains.rust-rover

      # ── Security & Crypto ───────────────────────────────────────────────
      keepassxc

      # ── Productivity & Office ───────────────────────────────────────────
      teams-for-linux
      libreoffice-fresh
      texliveFull        # LaTeX with full package collection
      drawio
      evince             # PDF viewer
      anki               # Flashcard learning
      gimp
      vlc
      handbrake
      kdePackages.ark              # archive manager (zip, tar, 7z, rar)
      kdePackages.gwenview         # image viewer
      kdePackages.kcalc            # calculator
      kdePackages.konsole          # terminal emulator
      kdePackages.kate             # text editor
      kdePackages.spectacle        # screenshot tool
      kdePackages.okular           # document / PDF viewer
      kdePackages.plasma-systemmonitor  # system monitor
      kdePackages.filelight        # disk usage analyzer
      kdePackages.kfind            # file search
      joplin-desktop     # Note-App
      joplin-cli

      # ── Network & VPN ───────────────────────────────────────────────────
      openconnect

      # ── System & Utilities ──────────────────────────────────────────────
      p7zip
      smartmontools
      hardinfo2
      lm_sensors
      dmidecode
      rclone             # Mount/sync SharePoint, OneDrive-Business, OneDrive

      # ── AI / ML ─────────────────────────────────────────────────────────
      ollama
      open-webui

      # ── Media ───────────────────────────────────────────────────────────
      haruna             # KDE video player with playlist/chapter UI

      # ── Security ────────────────────────────────────────────────────────
      hashcat            # GPU-accelerated password recovery / hash cracking

      # ── CLI Utilities ───────────────────────────────────────────────────
      ripgrep            # rg: fast grep replacement used by editors/scripts
      vorta              # GUI frontend for BorgBackup (browse/restore archives)

      # ── Windows Compatibility ────────────────────────────────────────────
      wineWow64Packages.stable  # run .exe files; 64-bit Wine (upstream preferred)

      # ── Languages ───────────────────────────────────────────────────────
      zig                # Zig toolchain (compiler + build system)

      # ── Misc ────────────────────────────────────────────────────────────
      discord
      ausweisapp
      solaar             # Logitech device manager
      proton-pass
      spotify
    ];
  };

  # Fish must be enabled system-wide so it is a valid login shell.
  programs.fish.enable = true;

  # Fish plugins — added to environment.systemPackages so NixOS places them
  # on the vendor path that fish sources automatically on startup.
  environment.systemPackages = with pkgs; [
    fishPlugins.pure     # minimal git-aware prompt (matches existing fish_variables)
    fishPlugins.autopair # auto-close brackets/quotes
  ];

  programs.zsh = {
    enable                    = true;
    autosuggestions.enable    = true;
    syntaxHighlighting.enable = true;
  };

  # Wireshark with setcap so non-root users in the wireshark group can capture
  programs.wireshark.enable = true;
}