# =============================================================================
# PAM Authentication – Fingerprint + YubiKey only (no password)
# =============================================================================
# Covers:
#   kscreenlocker – KDE screen lock
#   kde           – KDE auth (also used by the screen locker)
#   sddm          – login screen
#
# Recovery: Ctrl+Alt+F2 → TTY login still uses the `login` PAM service
#   which is untouched → password still works there.
#   Or select the previous NixOS generation at the boot menu.
# =============================================================================
{ lib, ... }:

{
  security.pam.u2f = {
    enable   = true;
    settings = {
      authfile = "/etc/nixos/secrets/u2f-mappings";
      cue      = true;
    };
  };

  # Remove password from all three relevant PAM services.
  # unixAuth = false removes pam_unix from the auth stack (= no password).
  # fprintAuth = true adds pam_fprintd as sufficient.
  # u2f is added automatically to all services by security.pam.u2f.enable above.
  security.pam.services.kscreenlocker = { unixAuth = lib.mkForce false; fprintAuth = lib.mkForce true; };
  security.pam.services.kde           = { unixAuth = lib.mkForce false; fprintAuth = lib.mkForce true; };
  security.pam.services.sddm          = { unixAuth = lib.mkForce false; fprintAuth = lib.mkForce true; };
}
