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
          --vfs-read-chunk-size 128M \
          --vfs-read-chunk-streams 4 \
          --dir-cache-time 24h \
          --timeout 30s \
          --no-gzip-encoding \
          --daemon
      '';
      ExecStop   = "/run/wrappers/bin/fusermount3 -u ${remote.path}";
      Restart    = "on-failure";
      RestartSec = 10;
      Environment = "PATH=/run/wrappers/bin:/run/current-system/sw/bin";
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
