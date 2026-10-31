# Hourly btrfs snapshots of @home and @configs (btrbk).
{ pkgs, ... }:

let
  inherit (import ./settings.nix) snapshotMount;

  # @nix, @docker and @flatpak are left out on purpose: all rebuildable.
  btrbkConfig = pkgs.writeText "btrbk.conf" ''
    timestamp_format        long
    snapshot_preserve_min   2h
    snapshot_preserve       24h 14d 8w 12m
    transaction_log         /var/log/btrbk.log
    snapshot_dir            ${snapshotMount}

    volume /home
      subvolume .
        snapshot_name home

    volume /etc/nixos
      subvolume .
        snapshot_name configs
  '';
in
{
  fileSystems."${snapshotMount}" = {
    device = "/dev/mapper/shared";
    fsType = "btrfs";
    options = [ "subvol=@snapshots" "compress=zstd" "noatime" ];
  };

  environment.systemPackages = [ pkgs.btrbk ];

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
}
