# =============================================================================
# Snapshot & Incremental Backup Configuration
# =============================================================================
#
# ARCHITECTURE
# ------------
#
#  Layer 1 – BTRFS Snapshots (local, on the 'shared' LUKS partition)
#    • Tool:      btrbk
#    • Location:  /.snapshots/ (@snapshots subvolume)
#    • Schedule:  hourly (keep 24h) + daily midnight (keep 14d/8w/12m)
#    • Purpose:   Fast local rollback. NOT a substitute for off-disk backup.
#
#  Layer 2 – BorgBackup to USB Drive A  (automatic)
#    • Triggered by a systemd timer (daily at 02:30)
#    • If Drive A is NOT mounted → exits cleanly, no error, no retry spam
#    • If the PC was off at 02:30 → Persistent=true catches up on next boot
#      (if drive is plugged in at that point; otherwise skipped cleanly)
#    • Interrupted backups resume from last checkpoint (every 5 min)
#
#  Layer 3 – BorgBackup to USB Drive B  (manual)
#    • NO timer – never runs automatically
#    • Trigger manually:
#        sudo systemctl start borgbackup-job-usb-manual
#    • Same drive-absent safety as Drive A
#
# USB DRIVE SETUP (run once per drive)
# -------------------------------------
#  Both drives must have a stable mount point. Best done via udev label:
#
#  1. Format & label the Borg partition (example, adjust /dev/sdX):
#       sudo mkfs.ext4 -L borg-usb-a /dev/sdX1   # or keep existing FS
#
#  2. Create mount points:
#       sudo mkdir -p /mnt/borg-usb-a /mnt/borg-usb-b
#
#  3. Add to /etc/nixos/backup.nix (already done below via fileSystems).
#     NixOS mounts them with 'nofail' so a missing drive doesn't block boot.
#
#  4. Initialise Borg repositories (drive must be plugged in):
#       export BORG_PASSPHRASE="your-strong-passphrase"
#       sudo borg init --encryption=repokey-blake2 /mnt/borg-usb-a/borg-repo
#       sudo borg init --encryption=repokey-blake2 /mnt/borg-usb-b/borg-repo
#
#  5. Store passphrase (same for both drives is fine, or use separate files):
#       sudo mkdir -p /etc/nixos/secrets
#       echo "your-strong-passphrase" | sudo tee /etc/nixos/secrets/borg-passphrase
#       sudo chmod 600 /etc/nixos/secrets/borg-passphrase
#
# MANUAL BACKUP COMMANDS
# ----------------------
#   Trigger Drive B backup now:
#     sudo systemctl start borgbackup-job-usb-manual
#
#   Check backup status / last run:
#     sudo systemctl status borgbackup-job-usb-a
#     sudo systemctl status borgbackup-job-usb-manual
#
#   List archives on a drive:
#     sudo BORG_PASSPHRASE=$(cat /etc/nixos/secrets/borg-passphrase) \
#       borg list /mnt/borg-usb-a/borg-repo
#
#   Restore a file (example):
#     sudo BORG_PASSPHRASE=$(cat /etc/nixos/secrets/borg-passphrase) \
#       borg extract /mnt/borg-usb-a/borg-repo::archive-name path/to/file
#
# =============================================================================

{ config, pkgs, lib, ... }:

let
  # --------------------------------------------------------------------------
  # CONFIGURATION – adjust to your environment
  # --------------------------------------------------------------------------

  # Passphrase file (chmod 600, owned by root)
  borgPassphraseFile = "/etc/nixos/secrets/borg-passphrase";

  # Mount points for the two USB drives
  usbMountA = "/mnt/borg-usb-a";
  usbMountB = "/mnt/borg-usb-b";

  # Borg repository paths on each drive
  borgRepoA = "${usbMountA}/borg-repo";
  borgRepoB = "${usbMountB}/borg-repo";

  # Filesystem labels used to auto-mount the drives (set when formatting)
  # These match the fileSystems entries below.
  usbLabelA = "borg-usb-a";
  usbLabelB = "borg-usb-b";

  # Snapshot mount point
  snapshotMount = "/.snapshots";

  # Device for the shared LUKS partition
  sharedDevice = "/dev/mapper/shared";

  # What to back up (same for both drives)
  backupPaths = [
    "/home"
    "/etc/nixos"
    "/var/lib/docker"
    "/var/lib/flatpak"
  ];

  backupExclude = [
    "pp:/.cache"
    "pp:/__pycache__"
    "pp:/.npm"
    "pp:/.cargo/registry"
    "pp:/.rustup"
    "pp:/.local/share/Trash"
    "/var/lib/docker/overlay2"
  ];

  # --------------------------------------------------------------------------
  # btrbk configuration
  # --------------------------------------------------------------------------
  btrbkConfig = pkgs.writeText "btrbk.conf" ''
    timestamp_format        long
    snapshot_preserve_min   2h
    snapshot_preserve       24h 14d 8w 12m
    transaction_log         /var/log/btrbk.log
    snapshot_dir            ${snapshotMount}

    # Root subvolume (on crypt_nixos)
    volume /
      subvolume .
        snapshot_name root

    # Subvolumes on the shared partition
    volume ${sharedDevice}
      subvolume @home
        snapshot_name home
      subvolume @configs
        snapshot_name configs
      subvolume @nix
        snapshot_name nix
      subvolume @docker
        snapshot_name docker
      subvolume @flatpak
        snapshot_name flatpak
  '';

  # --------------------------------------------------------------------------
  # Helper: wrapper script that runs Borg safely
  # – exits 0 (success) if the USB drive is not mounted, so systemd does
  #   not mark the unit as failed and does not spam the journal.
  # --------------------------------------------------------------------------
  makeBorgScript = { repo, mount, label, device }: pkgs.writeShellScript "borg-backup-${label}.sh" ''
    set -euo pipefail
    PASSPHRASE_FILE="${borgPassphraseFile}"
    REPO="${repo}"
    MOUNT="${mount}"
    DEVICE="${device}"

    # ── Try to mount if the device exists but isn't mounted yet ────────────
    mkdir -p "$MOUNT"
    if [ -b "$DEVICE" ] && ! ${pkgs.util-linux}/bin/mountpoint -q "$MOUNT"; then
      echo "[borg-${label}] Device found, mounting $DEVICE → $MOUNT"
      ${pkgs.util-linux}/bin/mount "$DEVICE" "$MOUNT" || true
    fi

    # ── Drive presence check ───────────────────────────────────────────────
    if ! ${pkgs.util-linux}/bin/mountpoint -q "$MOUNT"; then
      echo "[borg-${label}] Drive not connected or mountable – skipping backup." >&2
      exit 0
    fi

    # ── Passphrase ─────────────────────────────────────────────────────────
    if [ ! -f "$PASSPHRASE_FILE" ]; then
      echo "[borg-${label}] Passphrase file $PASSPHRASE_FILE not found!" >&2
      exit 1
    fi
    export BORG_PASSPHRASE
    BORG_PASSPHRASE=$(cat "$PASSPHRASE_FILE")

    ARCHIVE_NAME="${label}-$(date +%Y-%m-%dT%H:%M:%S)"

    echo "[borg-${label}] Starting backup → $REPO::$ARCHIVE_NAME"

    # ── Create archive ──────────────────────────────────────────────────────
    ${pkgs.borgbackup}/bin/borg create \
      --verbose \
      --stats \
      --show-rc \
      --compression auto,zstd \
      --checkpoint-interval 300 \
      --exclude-caches \
      ${lib.concatMapStringsSep " \\\n      " (e: "--exclude '${e}'") backupExclude} \
      "$REPO::$ARCHIVE_NAME" \
      ${lib.concatStringsSep " \\\n      " backupPaths}

    # ── Prune old archives ──────────────────────────────────────────────────
    echo "[borg-${label}] Pruning old archives…"
    ${pkgs.borgbackup}/bin/borg prune \
      --verbose \
      --list \
      --show-rc \
      --keep-daily  30 \
      --keep-weekly  8 \
      --keep-monthly 12 \
      --glob-archives "${label}-*" \
      "$REPO"

    # ── Compact (free disk space) ───────────────────────────────────────────
    ${pkgs.borgbackup}/bin/borg compact "$REPO"

    echo "[borg-${label}] Backup complete."
  '';

  borgScriptA      = makeBorgScript { repo = borgRepoA; mount = usbMountA; label = "usb-a"; device = "/dev/disk/by-label/${usbLabelA}"; };
  borgScriptManual = makeBorgScript { repo = borgRepoB; mount = usbMountB; label = "usb-b"; device = "/dev/disk/by-label/${usbLabelB}"; };

in
{
  # ==========================================================================
  # 1. USB Borg drive mounts are handled directly by the backup scripts
  #    (they detect the device by label and mount it on demand).
  #    No fileSystems entries needed – avoids systemd unit failures when
  #    drives are not connected at boot or rebuild time.
  # ==========================================================================

  # ==========================================================================
  # 2. @snapshots subvolume mount point
  # ==========================================================================
  fileSystems."${snapshotMount}" = {
    device = sharedDevice;
    fsType = "btrfs";
    options = [ "subvol=@snapshots" "compress=zstd" "noatime" ];
  };

  # ==========================================================================
  # 3. Packages & helper scripts
  # ==========================================================================
  environment.systemPackages = with pkgs; [
    btrbk       # BTRFS snapshot manager
    borgbackup  # Incremental backup
    borgmatic   # Borg wrapper

    # backup-status: single-command overview ─────────────────────────────────
    (pkgs.writeShellScriptBin "backup-status" ''
      PASS_FILE="${borgPassphraseFile}"
      REPO_A="${borgRepoA}"
      REPO_B="${borgRepoB}"
      MOUNT_A="${usbMountA}"
      MOUNT_B="${usbMountB}"
      SNAP="${snapshotMount}"

      bold()  { printf "\e[1m%s\e[0m\n" "$*"; }
      green() { printf "\e[32m%s\e[0m\n" "$*"; }
      red()   { printf "\e[31m%s\e[0m\n" "$*"; }
      dim()   { printf "\e[2m%s\e[0m\n"  "$*"; }

      echo ""
      bold "══════════════════════════════════════════"
      bold "  Backup Status Overview"
      bold "══════════════════════════════════════════"

      # Timers
      echo ""
      bold "● Systemd Timers"
      systemctl list-timers borgbackup-job-usb-a.timer btrbk.timer btrbk-daily.timer \
        --no-pager 2>/dev/null | grep -v "^$" || true

      # BTRFS snapshots
      echo ""
      bold "● BTRFS Snapshots ($SNAP)"
      if mountpoint -q "$SNAP" 2>/dev/null; then
        green "  Mounted ✓"
        COUNT=$(find "$SNAP" -maxdepth 2 -mindepth 2 -type d 2>/dev/null | wc -l)
        SIZE=$(du -sh "$SNAP" 2>/dev/null | cut -f1)
        echo "  Snapshots: $COUNT  |  Total size: $SIZE"
        echo "  Latest 5:"
        find "$SNAP" -maxdepth 2 -mindepth 2 -type d 2>/dev/null \
          | sort | tail -5 | while read s; do dim "    $s"; done
      else
        red "  $SNAP not mounted"
      fi

      # Drive A
      echo ""
      bold "● Borg Drive A  [automatic – daily 02:30]"
      if mountpoint -q "$MOUNT_A"; then
        green "  Drive: $MOUNT_A ✓"
        df -h "$MOUNT_A" | tail -1 | awk '{printf "  Space: used %s / %s  (%s)\n",$3,$2,$5}'
        if [ -f "$PASS_FILE" ] && [ -d "$REPO_A" ]; then
          echo "  Last 3 archives:"
          BORG_PASSPHRASE=$(cat "$PASS_FILE") borg list --last 3 --short "$REPO_A" \
            2>/dev/null | while read l; do dim "    $l"; done || dim "    (none yet)"
        else
          red "  Repo not initialised or passphrase missing"
        fi
      else
        red "  Drive A not connected ($MOUNT_A)"
      fi
      LAST_A=$(systemctl show borgbackup-job-usb-a.service \
        --property=ExecMainExitTimestamp --value 2>/dev/null)
      [ -n "$LAST_A" ] && echo "  Last run: $LAST_A"

      # Drive B
      echo ""
      bold "● Borg Drive B  [manual trigger]"
      bold "  To run: sudo systemctl start borgbackup-job-usb-manual"
      if mountpoint -q "$MOUNT_B"; then
        green "  Drive: $MOUNT_B ✓"
        df -h "$MOUNT_B" | tail -1 | awk '{printf "  Space: used %s / %s  (%s)\n",$3,$2,$5}'
        if [ -f "$PASS_FILE" ] && [ -d "$REPO_B" ]; then
          echo "  Last 3 archives:"
          BORG_PASSPHRASE=$(cat "$PASS_FILE") borg list --last 3 --short "$REPO_B" \
            2>/dev/null | while read l; do dim "    $l"; done || dim "    (none yet)"
        else
          red "  Repo not initialised or passphrase missing"
        fi
      else
        red "  Drive B not connected ($MOUNT_B)"
      fi
      LAST_B=$(systemctl show borgbackup-job-usb-manual.service \
        --property=ExecMainExitTimestamp --value 2>/dev/null)
      [ -n "$LAST_B" ] && echo "  Last run: $LAST_B"

      echo ""
      bold "══════════════════════════════════════════"
      echo "  Live log Drive A: sudo journalctl -fu borgbackup-job-usb-a"
      echo "  Live log Drive B: sudo journalctl -fu borgbackup-job-usb-manual"
      echo "  Live log btrbk:   sudo journalctl -fu btrbk"
      bold "══════════════════════════════════════════"
      echo ""
    '')
  ];

  # ==========================================================================
  # 4. btrbk – local BTRFS snapshots
  # ==========================================================================
  systemd.services.btrbk = {
    description = "btrbk BTRFS snapshot (hourly)";
    after       = [ "local-fs.target" ];
    requires    = [ "local-fs.target" ];
    serviceConfig = {
      Type           = "oneshot";
      ExecStart      = "${pkgs.btrbk}/bin/btrbk -c ${btrbkConfig} run";
      User           = "root";
      ProtectSystem  = "strict";
      ReadWritePaths = [ "/" snapshotMount "/var/log" ];
      PrivateTmp     = true;
    };
  };
  systemd.timers.btrbk = {
    description = "btrbk BTRFS snapshot (hourly)";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "hourly";
      Persistent         = true;   # catch up after sleep/poweroff
      RandomizedDelaySec = "5m";
    };
  };

  systemd.services.btrbk-daily = {
    description = "btrbk BTRFS snapshot (daily)";
    after       = [ "local-fs.target" ];
    requires    = [ "local-fs.target" ];
    serviceConfig = {
      Type           = "oneshot";
      ExecStart      = "${pkgs.btrbk}/bin/btrbk -c ${btrbkConfig} run";
      User           = "root";
      ProtectSystem  = "strict";
      ReadWritePaths = [ "/" snapshotMount "/var/log" ];
      PrivateTmp     = true;
    };
  };
  systemd.timers.btrbk-daily = {
    description = "btrbk BTRFS snapshot (daily midnight)";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "daily";
      Persistent         = true;
      RandomizedDelaySec = "10m";
    };
  };

  # ==========================================================================
  # 5. BorgBackup – Drive A  (AUTOMATIC, daily at 02:30)
  #
  # Behavior when drive is absent:
  #   • The wrapper script detects the missing mountpoint and exits 0
  #   • systemd sees success → no failed-unit, no spam
  #   • Persistent=true → if 02:30 was missed (PC off), runs on next boot
  #     If drive is still absent then → exits 0 again, skipped silently
  # ==========================================================================
  systemd.services.borgbackup-job-usb-a = {
    description = "BorgBackup → USB Drive A (automatic)";
    after       = [ "local-fs.target" "network.target" ];
    wants       = [ "local-fs.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = "${borgScriptA}";
      User      = "root";
      # Give Borg enough time to finish large first-run backups
      TimeoutStartSec = "6h";
      # Restart only on actual failures (not on clean skip)
      Restart   = "no";
    };
  };
  systemd.timers.borgbackup-job-usb-a = {
    description = "BorgBackup → USB Drive A (daily 02:30)";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "*-*-* 02:30:00";
      Persistent         = true;   # catch up after poweroff/sleep
      RandomizedDelaySec = "10m";  # avoid competing with btrbk at midnight
    };
  };

  # ==========================================================================
  # 6. BorgBackup – Drive B  (MANUAL, no timer)
  #
  # Trigger with:
  #   sudo systemctl start borgbackup-job-usb-manual
  #
  # Or add a desktop shortcut / alias:
  #   alias backup-usb-b='sudo systemctl start borgbackup-job-usb-manual && sudo journalctl -fu borgbackup-job-usb-manual'
  # ==========================================================================
  systemd.services.borgbackup-job-usb-manual = {
    description = "BorgBackup → USB Drive B (manual trigger)";
    after       = [ "local-fs.target" "network.target" ];
    wants       = [ "local-fs.target" ];
    # No corresponding timer – this unit is started manually only
    serviceConfig = {
      Type            = "oneshot";
      ExecStart       = "${borgScriptManual}";
      User            = "root";
      TimeoutStartSec = "6h";
      Restart         = "no";
    };
  };
}
