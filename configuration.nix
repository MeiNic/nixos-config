# Entry point. Every module is listed here, grouped by folder, so this list is
# the map of the whole configuration — nothing is auto-discovered.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix  # auto-generated hardware scan (gitignored)
    ./user.nix                    # account + login shell

    # ── System: boot, hardware, storage, Nix itself, network, locale ─────────
    ./system/boot.nix
    ./system/hardware.nix
    ./system/filesystems.nix
    ./system/nix.nix
    ./system/networking.nix
    ./system/locale.nix

    # ── Security: authentication, secrets, Git/SSH ──────────────────────────
    ./security/auth.nix
    ./security/secrets.nix
    ./security/git-ssh.nix

    # ── Desktop: Plasma session, apps, printing, mounts ─────────────────────
    ./desktop/plasma.nix
    ./desktop/apps.nix
    ./desktop/default-apps.nix
    ./desktop/printing.nix
    ./desktop/cloud-mounts.nix
    ./desktop/affinity.nix

    # ── Development: toolchains, VS Code, Flutter/Android ───────────────────
    ./development/tools.nix
    ./development/vscode.nix
    ./development/android.nix

    # ── Backup: snapshots, Borg, Android phone ──────────────────────────────
    ./backup/snapshots.nix
    ./backup/borg.nix
    ./backup/android.nix
    ./backup/status.nix
  ];

  # ── NixOS Release Version ──────────────────────────────────────────────────
  # Keep at the release used during initial install. Read the docs before
  # changing: man configuration.nix → system.stateVersion
  system.stateVersion = "25.11"; # Did you read the comment?
}
