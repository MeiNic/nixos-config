# =============================================================================
# Hardware, Power Management & Peripherals
# =============================================================================
{ pkgs, ... }:

{
  # ── Power Management ───────────────────────────────────────────────────────
  services.thermald.enable = true;

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
  hardware.logitech.wireless.enableGraphical = true;  # installs Solaar + auto-starts it in tray

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

  # ── udev Rules ─────────────────────────────────────────────────────────────
  services.udev.extraRules = ''
    # Ethernet expansion card (RTL8156): set USB autosuspend to 20 s
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="8156", ATTR{power/autosuspend}="20"

    # spd5118 (DDR5 RAM SPD hub: temperature + EEPROM) fails to resume after deep sleep
    ACTION=="add", SUBSYSTEM=="i2c", ATTR{name}=="spd5118", ATTR{power/async}="disabled"
  '';

  # ── System Packages (hardware-related) ─────────────────────────────────────
  environment.systemPackages = with pkgs; [
    linuxPackages_latest.turbostat   # CPU power/frequency stats (matches active kernel)
    btop
    btrfs-assistant   # BTRFS GUI (snapshots, subvols)
    duf               # modern df replacement
    fastfetch         # system info
    rsync             # file sync / remote copy
    framework-tool    # Framework-specific CLI (charge limit, LEDs, EC info)
  ];
}
