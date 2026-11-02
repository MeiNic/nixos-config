# Borg to the Hetzner Storage Box (offsite-backup: needs AC + ethernet) and to
# the USB hard drive (usb-backup: needs AC + the drive). Both run borg-job.sh
# with the same paths, excludes and retention. See README § Backup.
{ config, pkgs, lib, utils, ... }:

let
  inherit (import ../settings.nix) user usbDevice usbMount storageBoxKnownHosts;

  # Shared by both repos.
  passphraseFile = config.sops.secrets.offsite-backup-passphrase.path;

  # Gitignored, because this repo is public.
  storageBoxUser = (import ../secrets/personal.nix).offsiteStorageBoxUser;
  storageBoxHost = "${storageBoxUser}.your-storagebox.de";
  sshKeyFile     = config.sops.secrets.offsite-backup-ssh-key.path;

  # /var/lib/sops-nix holds the age key, which is in no snapshot.
  backupPaths = [ "/home/${user}" "/etc/nixos" "/var/lib/sops-nix" ];

  # hooks: condition() (required besides AC power), prepare()/release() (optional)
  jobs = {
    offsite-backup = {
      description = "Offsite backup to Hetzner Storage Box (needs AC power + ethernet)";
      title  = "Offsite backup";
      target = "the Storage Box";
      lost   = "power or ethernet";
      # Sub-accounts are chrooted to their home, hence "./".
      repo   = "ssh://${storageBoxUser}@${storageBoxHost}:23/./borg-repo";
      hooks  = ''
        condition() { nmcli -t -f TYPE,STATE device 2>/dev/null | grep -qx 'ethernet:connected'; }
        export BORG_REMOTE_PATH=borg-1.4
        export BORG_RSH="ssh -i ${sshKeyFile} -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${storageBoxKnownHosts} -o ServerAliveInterval=30 -o ServerAliveCountMax=4"
      '';
      packages = with pkgs; [ openssh networkmanager ];
      unit = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
      };
    };

    usb-backup = {
      description = "Backup to the USB hard drive (needs AC power + the drive)";
      title  = "USB backup";
      target = "the USB drive";
      lost   = "power or the drive";
      repo   = "${usbMount}/borg-repo";
      # Unmounts only what it mounted itself; lazily if the drive is already gone.
      hooks  = ''
        condition() { [ -b ${usbDevice} ]; }
        mounted_here=0
        prepare() {
          mountpoint -q ${usbMount} && return 0
          install -d -m 700 ${usbMount}
          mount -o noatime ${usbDevice} ${usbMount} || fail "cannot mount ${usbDevice}"
          mounted_here=1
        }
        release() {
          [ "$mounted_here" -eq 1 ] || return 0
          mounted_here=0
          umount ${usbMount} 2>/dev/null || umount -l ${usbMount}
          done_note="$done_note Unmounted - you can unplug the drive."
        }
      '';
      packages = [ ];
      unit.wantedBy = [ "${utils.escapeSystemdPath usbDevice}.device" ];   # start on plug-in
    };
  };

  mkScript = name: job: pkgs.writeShellScript name ''
    job=${name}
    state=/var/lib/${name}
    host=${config.networking.hostName}
    title=${lib.escapeShellArg job.title}
    target=${lib.escapeShellArg job.target}
    lost=${lib.escapeShellArg job.lost}
    repo=${lib.escapeShellArg job.repo}
    user=${user}
    excludes=${./borg-excludes.txt}
    paths=(${lib.escapeShellArgs backupPaths})
    export BORG_PASSCOMMAND="cat ${passphraseFile}"

    ${job.hooks}
    ${builtins.readFile ./borg-job.sh}
  '';
in
{
  environment.systemPackages = [ pkgs.borgbackup ];

  systemd.services = lib.mapAttrs (name: job: {
    inherit (job) description;
    path = with pkgs; [ borgbackup systemd util-linux libnotify jq ] ++ job.packages;
    # A rebuild must never kill a running backup.
    restartIfChanged = false;
    stopIfChanged    = false;
    serviceConfig = {
      Type              = "oneshot";
      User              = "root";
      ExecStart         = ''${pkgs.systemd}/bin/systemd-inhibit --what=sleep --who=${name} --why="${job.title} running" ${mkScript name job}'';
      TimeoutStartSec   = "infinity";
      Nice              = 19;
      IOSchedulingClass = "idle";
      StateDirectory    = name;
    };
  } // job.unit) jobs;

  systemd.timers = lib.mapAttrs (name: job: {
    description = "Poll for ${name} (10 min)";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnBootSec         = "5min";
      OnUnitInactiveSec = "10min";   # counted from the end of the last run, so runs never overlap
    };
  }) jobs;
}
