# =============================================================================
# Hardware, Boot & Power Management
# =============================================================================
{ config, pkgs, lib, ... }:

let
  luksUuidsPath = ./secrets/luks-uuids.nix;
  luksUuids = if builtins.pathExists luksUuidsPath then import luksUuidsPath else {
    cryptNixosUuid  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
    sharedUuid      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
    cachyosLuksUuid = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
    efiToken        = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
  };
in

{
  # ── Bootloader ─────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.useOSProber         = true;
  boot.initrd.systemd.enable           = true;   # modern boot system for FIDO2

  # CachyOS dual-boot entry
  # ── SENSITIVE: replace the EFI token path and LUKS UUID below with your ──
  # ── own values (found in hardware-configuration.nix / blkid output).    ──
  boot.loader.systemd-boot.extraEntries = {
    "cachyos.conf" = ''
      title    CachyOS
      linux    /${luksUuids.efiToken}/linux-cachyos/vmlinuz-linux-cachyos
      initrd   /intel-ucode.img
      initrd   /${luksUuids.efiToken}/linux-cachyos/initramfs-linux-cachyos
      options  rd.luks.uuid=${luksUuids.cachyosLuksUuid} root=/dev/mapper/luks-${luksUuids.cachyosLuksUuid} rootflags=subvol=/@ rw quiet nowatchdog splash
    '';
    # Alternative entry using cryptdevice (Arch-style mkinitcpio) as a backup
    # if dracut parameters fail.
    "cachyos-cryptdevice.conf" = ''
      title    CachyOS (mkinitcpio style)
      linux    /${luksUuids.efiToken}/linux-cachyos/vmlinuz-linux-cachyos
      initrd   /intel-ucode.img
      initrd   /${luksUuids.efiToken}/linux-cachyos/initramfs-linux-cachyos
      options  cryptdevice=UUID=${luksUuids.cachyosLuksUuid}:luks-${luksUuids.cachyosLuksUuid} root=/dev/mapper/luks-${luksUuids.cachyosLuksUuid} rootflags=subvol=/@ rw quiet splash
    '';

    # Chainload the other partition's EFI loader. Useful when the
    # Cachy partition maintains its own bootloader (you mentioned it does).
    # This points to the standard fallback EFI path - adjust if your
    # Cachy EFI file lives elsewhere under the token directory.
    "cachyos-chain.conf" = ''
      title    CachyOS (chainload)
      efi      /${luksUuids.efiToken}/EFI/BOOT/BOOTX64.EFI
    '';
  };

  # ── LUKS Encryption (FIDO2 / YubiKey unlock) ──────────────────────────────
  # crypt_nixos device UUID comes from hardware-configuration.nix (auto-generated).
  # We only add FIDO2 on top for crypt_nixos, and fully define the shared device
  # (not present in auto-generated config) here.
  boot.initrd.luks.devices = lib.mkMerge [
    {
      # Add FIDO2 to the auto-generated crypt_nixos entry
      "crypt_nixos".crypttabExtraOpts = [ "fido2-device=auto" ];
      # shared partition – not in hardware-configuration.nix, fully defined here
      "shared" = {
        device            = "/dev/disk/by-uuid/${luksUuids.sharedUuid}";
        crypttabExtraOpts = [ "fido2-device=auto" ];
      };
    }
  ];

  # ── Kernel ─────────────────────────────────────────────────────────────────
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Kernel parameters for Intel Core Ultra 155H (Meteor Lake) power tuning
  boot.kernelParams = [
    # Prevents keyboard backlight staying on during s2idle (~1 %/hr drain)
    "acpi_osi=\"!Windows 2020\""
    # Keeps CPU in PC10 deep C-states after suspend (without this: +2-4 W idle)
    "nvme.noacpi=1"
    # PCIe Active State Power Management: let the kernel pick the deepest safe
    # link-power state for every PCIe device (WiFi, NVMe, etc.)
    "pcie_aspm=powersupersave"
    # Intel GPU: enable all power-saving features (RC6, media-RC6, turbo)
    "i915.enable_rc6=7"
    # Framebuffer compression: reduces display memory bandwidth & GPU power
    "i915.enable_fbc=1"
  ];

  # NTFS userspace driver
  boot.supportedFilesystems = [ "ntfs" ];

  # ── Power Management ───────────────────────────────────────────────────────
  services.thermald.enable = true;

  # Reduce kernel VM wakeups — less timer interrupts = deeper C-states
  boot.kernel.sysctl = {
    "kernel.nmi_watchdog"          = 0;     # disable NMI watchdog (saves ~1 W)
    "vm.dirty_writeback_centisecs" = 6000;  # flush dirty pages every 60 s (default: 5 s)
    "vm.laptop_mode"               = 5;     # batch disk writes
  };

  # powertop --auto-tune at boot: enables runtime PM for USB, PCIe & audio
  powerManagement.powertop.enable = true;

  # auto-cpufreq: dynamically adjusts EPP (Energy Performance Preference) and
  # turbo based on actual CPU load + AC/battery state. This fixes the root
  # cause of high idle temperatures: power-profiles-daemon's "balanced" mode
  # sets EPP=balance_performance, keeping cores hot even at low load.
  # power-profiles-daemon is pulled in by Cinnamon but conflicts with auto-cpufreq.
  services.power-profiles-daemon.enable = false;
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      energy_performance_preference = "power";
      turbo = "never";
    };
    charger = {
      governor = "powersave";
      energy_performance_preference = "balance_power";
      turbo = "auto";  # only boosts when load actually demands it
    };
  };

  # Suspend-then-hibernate (requires swap >= RAM):
  # systemd.sleep.extraConfig = ''
  #   HibernateDelaySec=20min
  # '';
  # services.logind.lidSwitch = "suspend-then-hibernate";

  # AX210 Wi-Fi: disable Wi-Fi 6/6E if needed:
  # boot.extraModprobeConfig = ''
  #   options iwlwifi disable_11ax=Y
  # '';

  # ── Bluetooth ──────────────────────────────────────────────────────────────
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.settings.General.Experimental = true;

  # ── Firmware ───────────────────────────────────────────────────────────────
  hardware.enableAllFirmware = true;
  services.fwupd.enable      = true;

  # ── YubiKey / Smart-Card ───────────────────────────────────────────────────
  services.pcscd.enable = true;

  # ── System Packages (hardware-related) ─────────────────────────────────────
  environment.systemPackages = with pkgs; [
    yubikey-manager
    powertop
    auto-cpufreq
    linuxPackages.turbostat
    btop
    mission-center
    ntfs3g
  ];
}
