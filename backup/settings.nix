# Values shared by the modules in this folder (plain attrset, not a module).
{
  user          = "nico";
  snapshotMount = "/.snapshots";
  # "backup" partition of the USB hard drive; usb-backup mounts it only while running.
  usbDevice     = "/dev/disk/by-uuid/246f76d5-4bfd-48d6-8ada-e8c131709ba6";
  usbMount      = "/mnt/backup-hdd";
}
