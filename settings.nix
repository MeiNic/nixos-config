# Non-secret values shared by several modules (plain attrset, not a module).
{
  user                 = "nico";
  # btrbk target (backup/snapshots.nix); the mount is in system/filesystems.nix.
  snapshotMount        = "/.snapshots";
  # "backup" partition of the USB hard drive; usb-backup mounts it only while running.
  usbDevice            = "/dev/disk/by-uuid/246f76d5-4bfd-48d6-8ada-e8c131709ba6";
  usbMount             = "/mnt/backup-hdd";
  # Storage Box SSH host keys, for pinning only - not a secret, so a plain file.
  storageBoxKnownHosts = "/etc/nixos/secrets/hetzner-storagebox-known_hosts";
}
