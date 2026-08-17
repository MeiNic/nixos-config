# =============================================================================
# Android phone backup → Hetzner Storage Box
# =============================================================================
# open-android-backup (vendored + patched, see ./patches/) makes a
# password-encrypted 7z archive here, then rclone uploads it over SFTP to a
# Hetzner Storage Box; the local copy is deleted once uploaded (no local
# retention) and the remote is pruned to the last N archives.
#
# android-backup-auto: apps + storage, fired by udev on USB connect.
# android-backup-manual: also contacts (needs a physical tap of "Export Data"
# on the phone - not automatable) - run yourself: systemctl start android-backup-manual
#
# No sops-nix/agenix here; secrets follow backup.nix's existing convention
# (borgPassphraseFile): plain root-owned files under secrets/, referenced
# only by path and read at runtime, never imported into Nix.
{ config, pkgs, lib, ... }:

let
  archivePasswordFile = "/etc/nixos/secrets/android-backup.env";
  sshKeyFile           = "/etc/nixos/secrets/hetzner-storagebox.key";
  knownHostsFile       = "/etc/nixos/secrets/hetzner-storagebox-known_hosts";

  storageBoxUser = "u643857-sub4";
  storageBoxHost = "u643857-sub4.your-storagebox.de";
  storageBoxPort = 23;
  remotePath     = "android-backup"; # no leading slash - Hetzner requirement
  keepRemote     = 5;                # archives kept on the Storage Box

  # Already synced to the Storage Box some other way - dropped from staging
  # before compression via the backup_hook below, never archived at all.
  excludeStoragePaths = [ "DCIM" "Pictures" ];

  # Not /var/lib (root fs, crypt_nixos, small): phone backups run tens of GB
  # and upstream's space check roughly doubles that when staging and CWD
  # share a device. /home is the big `shared` LUKS partition.
  stateDir   = "/home/android-backup";
  stagingDir = "${stateDir}/staging";

  # Vendored open-android-backup, pinned + patched.
  openAndroidBackupSrc = pkgs.fetchFromGitHub {
    owner = "mrrfv";
    repo  = "open-android-backup";
    rev   = "1536ae59e11aaed160fcf273e45fc7250b33d9fb"; # tag v1.2.3
    hash  = "sha256-k6fo/9JcmMd+f8ijshwow3kOe1UiJeUrptRWRwl9hMY=";
  };

  openAndroidBackup = pkgs.stdenvNoCC.mkDerivation {
    pname   = "open-android-backup";
    version = "1.2.3";
    src     = openAndroidBackupSrc;

    # 4 runtime fixes for headless/unattended operation (whiptail checklist
    # hang, a read-only-store permission bug, an empty-password bug in the
    # 7z encryption step, and a set -e-swallowed low-space check) - see
    # patches/open-android-backup-nixos-unattended-fixes.patch for details.
    patches = [ ./patches/open-android-backup-nixos-unattended-fixes.patch ];

    dontBuild = true;
    installPhase = ''
      mkdir -p "$out"
      cp -r . "$out"/
      chmod +x "$out"/backup.sh
    '';
  };

  # backup_hook is open-android-backup's supported extension point
  # (use_hooks=yes + ./hooks.sh) - runs after storage/apps/contacts are
  # copied but before compression.
  hooksScript = pkgs.writeText "android-backup-hooks.sh" ''
    function backup_hook() {
      ${lib.concatMapStringsSep "\n      " (dir: ''
        if [ -d "$BACKUP_TMP_DIR/Storage/${dir}" ]; then
          cecho "Excluding ${dir} from this backup (synced elsewhere already) - removing staged copy."
          rm -rf "$BACKUP_TMP_DIR/Storage/${dir}"
        fi
      '') excludeStoragePaths}
    }

    # No-op: silences upstream's "after_backup_hook not found" warning/sleep.
    function after_backup_hook() { :; }
  '';

  # No rclone.conf: SFTP params passed as CLI flags via rclone's "on the fly"
  # remote syntax (:sftp:path), so only the key *path* touches the store.
  sftpFlags = lib.concatStringsSep " " [
    "--sftp-host ${storageBoxHost}"
    "--sftp-port ${toString storageBoxPort}"
    "--sftp-user ${storageBoxUser}"
    "--sftp-key-file ${sshKeyFile}"
    "--sftp-known-hosts-file ${knownHostsFile}"
    "--sftp-shell-type unix"
  ];

  uploadAndPrune = pkgs.writeShellScript "android-backup-upload.sh" ''
    set -euo pipefail
    shopt -s nullglob

    archives=(${stagingDir}/open-android-backup-*.7z)
    if [ ''${#archives[@]} -eq 0 ]; then
      echo "No staged archive found - nothing to upload."
      exit 0
    fi

    for archive in "''${archives[@]}"; do
      echo "Uploading $(basename "$archive") to the Storage Box..."
      rclone copyto "$archive" ":sftp:${remotePath}/$(basename "$archive")" ${sftpFlags}
      echo "Upload confirmed - removing local copy (no local retention configured)."
      rm -f "$archive"
    done

    echo "Pruning remote archives, keeping the last ${toString keepRemote}..."
    # Sort by remote mtime, not filename - upstream names are MM-DD-YYYY-
    # prefixed, which doesn't sort chronologically.
    mapfile -t remote_entries < <(
      rclone lsf ":sftp:${remotePath}" ${sftpFlags} --format "tp" --separator $'\t' | sort
    )
    stale=$(( ''${#remote_entries[@]} - ${toString keepRemote} ))
    if [ "$stale" -gt 0 ]; then
      for entry in "''${remote_entries[@]:0:$stale}"; do
        fname="''${entry#*$'\t'}"
        echo "Deleting old remote archive: $fname"
        rclone deletefile ":sftp:${remotePath}/$fname" ${sftpFlags}
      done
    fi
  '';

  mkAndroidBackupScript = { includeContacts }: pkgs.writeShellScript
    "android-backup-${if includeContacts then "manual" else "auto"}.sh" ''
    set -euo pipefail
    mkdir -p "${stagingDir}"
    chown -R nico:users "${stateDir}"
    cd "${stateDir}"

    # backup.sh sources ./hooks.sh relative to CWD, not its own store path.
    ln -sf "${hooksScript}" "${stateDir}/hooks.sh"

    export unattended_mode=1
    export selected_action=Backup
    export mode=Wired
    export export_method=tar
    export use_hooks=yes
    export compression_level=5
    export archive_path="${stagingDir}"
    export backup_apps=yes
    export backup_storage=yes
    ${if includeContacts then ''
      export backup_contacts=yes
      echo "Contacts requested: open the companion app on the phone and press 'Export Data' when it appears."
    '' else ''
      export backup_contacts=no
      # CI=1 skips the companion app entirely - only needed for contacts.
      export CI=1
    ''}

    if [ -z "''${archive_password:-}" ]; then
      echo "archive_password is not set - check ${archivePasswordFile}" >&2
      exit 1
    fi

    ${openAndroidBackup}/backup.sh

    ${uploadAndPrune}
  '';

  androidBackupPath = lib.makeBinPath [
    pkgs.android-tools
    pkgs.p7zip
    pkgs.gnutar
    pkgs.pv
    pkgs.bc
    pkgs.curl
    pkgs.newt # whiptail
    pkgs.ncurses # clear/tput - backup.sh calls bare `clear` unconditionally
    pkgs.rclone
    pkgs.openssh
    pkgs.coreutils
    pkgs.gnused
    pkgs.gawk
    pkgs.gnugrep
    pkgs.findutils
    pkgs.util-linux
  ];

  mkAndroidBackupService = { includeContacts }: {
    description =
      if includeContacts
      then "Android phone backup (full, incl. contacts - run manually while present)"
      else "Android phone backup (apps + storage - automatic on USB connect)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type             = "oneshot";
      User             = "root";
      # No StateDirectory/WorkingDirectory: stateDir is under /home, not
      # /var/lib, so the script mkdir -p's and cd's into it itself.
      # HOME=nico's so adb reuses the already-authorized ~/.android/adbkey
      # (persists fine - /home is a real subvolume, no impermanence here).
      # TERM=xterm: systemd's default TERM=dumb has no "clear" capability,
      # and backup.sh calls bare `clear` unconditionally under set -e.
      Environment      = [ "HOME=/home/nico" "PATH=${androidBackupPath}" "TERM=xterm" ];
      EnvironmentFile  = archivePasswordFile;
      ExecStart        = "${mkAndroidBackupScript { inherit includeContacts; }}";
      # No cap: covers phone copy + compression + upload combined, and a 20G+
      # archive over a 50 Mbit uplink alone can take the better part of an
      # hour. Nothing else is blocked on this (oneshot, Restart=no).
      TimeoutStartSec  = "infinity";
      Restart          = "no";
    };
  };
in
{
  systemd.services.android-backup-auto   = mkAndroidBackupService { includeContacts = false; };
  systemd.services.android-backup-manual = mkAndroidBackupService { includeContacts = true;  };

  # Fires on the standard ADB USB interface (class ff/subclass 42/protocol
  # 01), not a vendor ID - works for any Android phone with debugging on.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="ff", ATTR{bInterfaceSubClass}=="42", ATTR{bInterfaceProtocol}=="01", TAG+="systemd", ENV{SYSTEMD_WANTS}+="android-backup-auto.service"
  '';
}
