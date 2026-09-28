# =============================================================================
# Cloud storage mounts via rclone (parameterized for multiple remotes)
# =============================================================================
# One-time manual setup required: configure remotes via `rclone config`

{ pkgs, ... }:

let
  user = "nico";
  remotes = [
    { name = "onedrive"; path = "/home/${user}/OneDrive"; }
    { name = "storagebox"; path = "/home/${user}/StorageBox"; }
    { name = "pictures-smartphone"; path = "/home/${user}/pictures-smartphone"; }
  ];

  mkRcloneService = remote: {
    description = "Mount ${remote.name} via rclone";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    wantedBy    = [ "default.target" ];

    serviceConfig = {
      Type = "forking";
      ExecStartPre = ''
        ${pkgs.bash}/bin/bash -c \
          "/run/wrappers/bin/fusermount3 -u ${remote.path} 2>/dev/null || true && \
           ${pkgs.coreutils}/bin/mkdir -p ${remote.path}"
      '';
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount ${remote.name}: ${remote.path} \
          --vfs-cache-mode full \
          --vfs-cache-max-size 20G \
          --vfs-cache-max-age 48h \
          --vfs-cache-min-free-space 5G \
          --vfs-read-chunk-size 128M \
          --vfs-read-chunk-streams 4 \
          --vfs-fast-fingerprint \
          --dir-cache-time 24h \
          --poll-interval 1m \
          --attr-timeout 1h \
          --buffer-size 32M \
          --transfers 8 \
          --timeout 30s \
          --no-gzip-encoding \
          --daemon
      '';
      ExecStop   = "/run/wrappers/bin/fusermount3 -u ${remote.path}";
      Restart    = "on-failure";
      RestartSec = 10;
      Environment = "PATH=/run/wrappers/bin:/run/current-system/sw/bin";
      # Keep background cache fill/eviction from starving desktop I/O when a
      # large folder is opened (the actual source of "not responding" hangs).
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };
  };
in
{
  programs.fuse.userAllowOther = true;

  systemd.user.services = builtins.listToAttrs
    (map (remote: {
      name = "rclone-${remote.name}";
      value = mkRcloneService remote;
    }) remotes);
}
