# =============================================================================
# Desktop Environment, Display & Input
# =============================================================================
{ pkgs, ... }:

{
  # ── Display Manager & Desktop Environment ─────────────────────────────────
  services.xserver.enable = true;

  # KDE Plasma 6 + SDDM
  services.displayManager.sddm.enable    = true;
  services.desktopManager.plasma6.enable = true;

  # ── Keyboard Layout ────────────────────────────────────────────────────────
  services.xserver.xkb.layout = "de";

  console.keyMap = "de";

  # ── Audio (PipeWire) ───────────────────────────────────────────────────────
  security.rtkit.enable = true;

  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
    wireplumber.enable = true;
  };

  # ── Printing ───────────────────────────────────────────────────────────────
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    gutenprint
    gutenprintBin
    ghostscript
  ];

  # ── Fingerprint Sensor ────────────────────────────────────────────────────
  # We deliberately do NOT use `services.fprintd.enable`, because that flips
  # NixOS's per-service `fprintAuth` default to true — adding the fingerprint as
  # a *sole* auth factor to sudo, login, polkit, sshd, etc. Our security model
  # (security-auth.nix) permits the fingerprint only as the mandatory 2nd factor
  # at the KDE lock screen, never on its own. So we provision just the daemon
  # (identical to what `enable` does) and leave the global `fprintAuth` at false.
  systemd.packages       = [ pkgs.fprintd ];
  services.dbus.packages = [ pkgs.fprintd ];
  # fprintd CLI tools (fprintd-enroll/-list/-verify) are added to
  # environment.systemPackages below.

  # The Goodix MOC sensor gets stuck in fprintd's "suspended" state across a
  # lid-close suspend: the resume signal races with the lock screen grabbing the
  # device, so every identify fails instantly with "Cannot run while suspended"
  # (looks like a spurious read with no finger on the sensor). Forcing fprintd to
  # restart on resume clears the stuck state. try-restart is a no-op when fprintd
  # has already deactivated (it is D-Bus activated), so there is nothing to clear.
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl try-restart fprintd.service
  '';

  # ── Fonts ──────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts-color-emoji    # colour emoji (avoids □ boxes in browser/apps)
    liberation_ttf      # Arial/Times/Courier drop-ins for Office doc compat
    nerd-fonts.meslo-lg # MesloLGS icons for the zsh powerline prompt
  ];

  # ── System Packages (desktop-related) ─────────────────────────────────────
  environment.systemPackages = with pkgs; [
    pavucontrol # graphical mixer: route apps to different audio outputs
    fprintd     # fingerprint daemon + CLI (enroll/list/verify); see note above
  ];
}
