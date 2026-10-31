# Backup: btrfs snapshots, Borg (offsite + USB drive) and `backup-status`. See README § Backup.
{ pkgs, lib, ... }:

let
  inherit (import ./settings.nix) snapshotMount usbDevice;
in
{
  imports = [ ./snapshots.nix ./borg.nix ];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "backup-status" ''
      SNAP=${snapshotMount}
      USB_DEVICE=${usbDevice}
      PATH=${lib.makeBinPath [ pkgs.networkmanager pkgs.systemd ]}:$PATH
      ${builtins.readFile ./backup-status.sh}
    '')
  ];
}
