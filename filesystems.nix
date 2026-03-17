# =============================================================================
# Filesystems (btrfs subvolumes on shared LUKS partition)
# =============================================================================
{ ... }:

{
  fileSystems."/nix" = {
    device        = "/dev/mapper/shared";
    fsType        = "btrfs";
    options       = [ "subvol=@nix" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };

  fileSystems."/home" = {
    device        = "/dev/mapper/shared";
    fsType        = "btrfs";
    options       = [ "subvol=@home" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };


  fileSystems."/var/lib/docker" = {
    device        = "/dev/mapper/shared";
    fsType        = "btrfs";
    options       = [ "subvol=@docker" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };

  fileSystems."/var/lib/flatpak" = {
    device        = "/dev/mapper/shared";
    fsType        = "btrfs";
    options       = [ "subvol=@flatpak" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };

  fileSystems."/etc/nixos" = {
    device        = "/dev/mapper/shared";
    fsType        = "btrfs";
    options       = [ "subvol=@configs" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };
}
