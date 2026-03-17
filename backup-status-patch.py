import re

with open('/etc/nixos/backup.nix', 'r') as f:
    content = f.read()

old = """  # ==========================================================================
  # 3. Packages
  # ==========================================================================
  environment.systemPackages = with pkgs; [
    btrbk       # BTRFS snapshot manager  (CLI: sudo btrbk -c /path/to.conf run)
    borgbackup  # Incremental backup      (CLI: sudo borg list /mnt/borg-usb-a/borg-repo)
    borgmatic   # Borg wrapper            (CLI: sudo borgmatic --verbosity 1)
  ];"""

new = r"""  # ==========================================================================
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
  ];"""

if old in content:
    content = content.replace(old, new, 1)
    with open('/etc/nixos/backup.nix', 'w') as f:
        f.write(content)
    print("Patched OK")
else:
    print("ERROR: old string not found")
