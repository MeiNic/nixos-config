# =============================================================================
# Plasma Desktop Session: display manager, audio, fonts
# =============================================================================
# Keyboard layout: system/locale.nix. Fingerprint daemon: security/auth.nix.
{ pkgs, ... }:

{
  # ── Display Manager & Desktop Environment ─────────────────────────────────
  services.xserver.enable = true;

  # KDE Plasma 6 + SDDM
  services.displayManager.sddm.enable    = true;
  services.desktopManager.plasma6.enable = true;

  # ── Audio (PipeWire) ───────────────────────────────────────────────────────
  security.rtkit.enable = true;

  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
    wireplumber.enable = true;
  };

  # ── Fonts ──────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts-color-emoji    # colour emoji (avoids □ boxes in browser/apps)
    liberation_ttf      # Arial/Times/Courier drop-ins for Office doc compat
    corefonts           # genuine Arial/Helvetica/Times New Roman (Typst needs exact family names)
    nerd-fonts.meslo-lg # MesloLGS Nerd Font (powerline/icon glyphs for terminal prompts)
  ];

  # ── System Packages (desktop-related) ─────────────────────────────────────
  environment.systemPackages = with pkgs; [
    pavucontrol # graphical mixer: route apps to different audio outputs
  ];
}
