# =============================================================================
# Filesystems (btrfs subvolumes on shared LUKS partition)
# =============================================================================
{ ... }:

let
  mkBtrfs = subvol: {
    device        = "/dev/mapper/shared";
    fsType        = "btrfs";
    options       = [ "subvol=${subvol}" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };
in
{
  fileSystems."/nix"             = mkBtrfs "@nix";
  fileSystems."/home"            = mkBtrfs "@home";
  fileSystems."/var/lib/docker"  = mkBtrfs "@docker";
  fileSystems."/var/lib/flatpak" = mkBtrfs "@flatpak";
  fileSystems."/etc/nixos"       = mkBtrfs "@configs";
}
