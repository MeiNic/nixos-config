# =============================================================================
# Hardware, Boot & Power Management
# =============================================================================
{ pkgs, ... }:

let
  luksUuidsPath = ./secrets/luks-uuids.nix;
  luksUuids = if builtins.pathExists luksUuidsPath then import luksUuidsPath else {
    sharedUuid = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
  };
in

{
  # ── Bootloader ─────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable           = true;   # modern boot system for FIDO2

  # ── LUKS Encryption (FIDO2 / YubiKey unlock) ──────────────────────────────
  # crypt_nixos device UUID comes from hardware-configuration.nix (auto-generated).
  # We only add FIDO2 on top for crypt_nixos, and fully define the shared device
  # (not present in auto-generated config) here.
  boot.initrd.luks.devices = {
    # Add FIDO2 to the auto-generated crypt_nixos entry
    "crypt_nixos".crypttabExtraOpts = [ "fido2-device=auto" ];
    # shared partition – not in hardware-configuration.nix, fully defined here
    "shared" = {
      device            = "/dev/disk/by-uuid/${luksUuids.sharedUuid}";
      crypttabExtraOpts = [ "fido2-device=auto" ];
    };
  };

  # ── Kernel ─────────────────────────────────────────────────────────────────
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Framework EC doesn't use this module; suppresses a misleading boot error
  boot.blacklistedKernelModules = [ "cros-usbpd-charger" ];

  # Kernel parameters for Intel Core Ultra 155H (Meteor Lake) power tuning
  boot.kernelParams = [
    # Prevents keyboard backlight staying on during s2idle (~1 %/hr drain)
    "acpi_osi=\"!Windows 2020\""
    # Keeps CPU in PC10 deep C-states after suspend (without this: +2-4 W idle)
    "nvme.noacpi=1"
    # PCIe Active State Power Management: let the kernel pick the deepest safe
    # link-power state for every PCIe device (WiFi, NVMe, etc.)
    "pcie_aspm=powersupersave"
  ];

  # NTFS userspace driver
  boot.supportedFilesystems = [ "ntfs" ];

  # ── Power Management ───────────────────────────────────────────────────────
  services.thermald.enable = true;

  # Reduce kernel VM wakeups — less timer interrupts = deeper C-states
  boot.kernel.sysctl = {
    # NMI watchdog re-enabled (~1 W cost) after a string of silent hard
    # freezes (screen dies, nothing in the journal — kernel never got a
    # chance to log anything). *_panic=1 turns a detected soft/hard lockup
    # into an actual panic so it gets written to pstore (/sys/fs/pstore,
    # already mounted via EFI vars) instead of just printing a warning that
    # may never reach disk if the freeze is real. kernel.panic=10 auto-
    # reboots 10s after, giving pstore time to flush.
    "kernel.nmi_watchdog"          = 1;
    "kernel.hardlockup_panic"      = 1;
    "kernel.softlockup_panic"      = 1;
    "kernel.panic"                 = 10;
    # zram-tuned: prefer compressing anon pages over evicting code-page cache.
    "vm.swappiness"                = 180;
    "vm.watermark_boost_factor"    = 0;
    "vm.watermark_scale_factor"    = 125;
  };

  # ── Memory Pressure / OOM Protection ───────────────────────────────────────
  # Without swap or an OOM daemon, full RAM (LLMs, JVMs, Docker) made the kernel
  # thrash code pages to NVMe and freeze hard. zram adds compressed swap
  # headroom; earlyoom kills the hog before the freeze (the kernel's own OOM
  # killer reacts too late).
  zramSwap = {
    enable        = true;
    algorithm     = "zstd";
    memoryPercent = 50;
  };

  services.earlyoom = {
    enable                 = true;
    freeMemThreshold       = 5;   # start killing when <5 % RAM free …
    freeSwapThreshold      = 10;  # … and <10 % (zram) swap free
    enableNotifications    = true;
    # Prefer to kill memory hogs; never kill the session/critical daemons.
    extraArgs = [
      "--prefer" "^(ollama|open-webui|java|chrome|brave|firefox|electron)$"
      "--avoid"  "^(systemd|sddm|plasmashell|kwin_wayland|Xorg|sshd|dbus-daemon)$"
    ];
  };

  # powertop --auto-tune at boot: enables runtime PM for USB, PCIe & audio
  powerManagement.powertop.enable = true;

  services.power-profiles-daemon.enable = true;

  # ── Wi-Fi (Intel AX210, Wi-Fi 6E) ──────────────────────────────────────────
  # The 6 GHz band stays disabled under the world ("00") regulatory domain, so
  # pin it to the actual country to unlock the 6E channels.
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=DE
  '';

  # ── Logitech Peripherals ───────────────────────────────────────────────────
  hardware.logitech.wireless.enable         = true;  # udev rules for Unifying/Bolt receivers
  hardware.logitech.wireless.enableGraphical = true;  # auto-start Solaar in tray

  # ── Bluetooth ──────────────────────────────────────────────────────────────
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.settings.General.Experimental = true;

  # ── Firmware ───────────────────────────────────────────────────────────────
  hardware.enableAllFirmware = true;
  services.fwupd.enable      = true;

  # ── Intel Arc / Xe Graphics ────────────────────────────────────────────────
  hardware.graphics = {
    enable         = true;
    enable32Bit    = true;                          # required for Wine 32-bit apps
    extraPackages  = [ pkgs.intel-media-driver ];   # VAAPI hardware video decoding
  };

  # ── Thunderbolt ────────────────────────────────────────────────────────────
  services.hardware.bolt.enable = true;   # device authorization / security daemon

  # ── YubiKey / Smart-Card ───────────────────────────────────────────────────
  services.pcscd.enable = true;

  # ── udev Rules ─────────────────────────────────────────────────────────────
  services.udev.extraRules = ''
    # Ethernet expansion card (RTL8156): set USB autosuspend to 20 s
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="8156", ATTR{power/autosuspend}="20"

    # spd5118 (DDR5 RAM SPD hub: temperature + EEPROM) fails to resume after deep sleep
    ACTION=="add", SUBSYSTEM=="i2c", ATTR{name}=="spd5118", ATTR{power/async}="disabled"
  '';

  # ── System Packages (hardware-related) ─────────────────────────────────────
  environment.systemPackages = with pkgs; [
    yubikey-manager
    linuxPackages_latest.turbostat   # CPU power/frequency stats (matches active kernel)
    btop
    ntfs3g
    btrfs-assistant   # BTRFS GUI (snapshots, subvols)
    duf               # modern df replacement
    fastfetch         # system info
    rsync             # file sync / remote copy
    framework-tool    # Framework-specific CLI (charge limit, LEDs, EC info)
  ];
}
