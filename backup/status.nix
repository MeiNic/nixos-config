# `backup-status`: one overview of btrbk snapshots and both Borg jobs. See README § Backup.
{ pkgs, lib, ... }:

let
  inherit (import ../settings.nix) snapshotMount usbDevice;
in
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "backup-status" ''
      SNAP=${snapshotMount}
      USB_DEVICE=${usbDevice}
      PATH=${lib.makeBinPath [ pkgs.networkmanager pkgs.systemd ]}:$PATH
      ${builtins.readFile ./backup-status.sh}
    '')
  ];
}
