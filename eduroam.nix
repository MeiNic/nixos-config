# =============================================================================
# eduroam.nix  –  eduroam Wi-Fi via EAP-TLS (certificate, no password)
# =============================================================================
#
# Connects to eduroam using a client certificate instead of a username and
# password. Works at any eduroam campus worldwide: authentication is always
# routed back to your home institution's RADIUS server.
#
# ── Setting this up (also for a different user / institution) ─────────────────
#
# 1. Obtain your personal eduroam client certificate as a PKCS#12 (.p12) file
#    from your institution — e.g. the easyroam app/portal (DFN), or your
#    university's geteduroam / eduroam CAT profile.
#
# 2. Extract the public cert and the (unencrypted) private key into certs/.
#    Replace YOUR.p12, and put the .p12 password after `pass:` (leave empty if
#    it has none). `-legacy` is needed for older RC2-encrypted .p12 files and
#    is harmless otherwise:
#
#      mkdir -p /etc/nixos/certs
#      openssl pkcs12 -legacy -in YOUR.p12 -clcerts -nokeys -passin pass: \
#        | openssl x509 -out /etc/nixos/certs/eduroam-client.pem
#      openssl pkcs12 -legacy -in YOUR.p12 -nocerts -nodes  -passin pass: \
#        | openssl pkey  -out /etc/nixos/certs/eduroam-key.pem
#
#    (certs/ is gitignored — the private key never enters git or the Nix store.)
#
# 3. Fill in your per-user values:
#      cp secrets/eduroam.nix.template secrets/eduroam.nix
#    then edit secrets/eduroam.nix (it documents how to find each value).
#
# 4. Import this file from configuration.nix and run nixos-rebuild switch.
#    eduroam then connects automatically whenever it is in range.
# =============================================================================

{ ... }:

let
  inherit (import ./secrets/eduroam.nix) identity domainSuffixMatch;
in
{
  # wpa_supplicant runs as its own user, so it must own the cert/key to read
  # them (otherwise EAP-TLS fails with "Permission denied" loading the key).
  systemd.tmpfiles.rules = [
    "z /etc/nixos/certs/eduroam-key.pem    0400 wpa_supplicant wpa_supplicant - -"
    "z /etc/nixos/certs/eduroam-client.pem 0444 wpa_supplicant wpa_supplicant - -"
  ];

  networking.networkmanager.ensureProfiles.profiles = {
    eduroam = {
      connection = {
        id          = "eduroam";
        # Arbitrary; generate a fresh one with `uuidgen` if you like.
        uuid        = "3ae3dbfa-b53f-4070-8f24-c691acfd2270";
        type        = "wifi";
        autoconnect = "true";
      };
      wifi = {
        ssid = "eduroam";
        mode = "infrastructure";
      };
      "wifi-security" = {
        key-mgmt = "wpa-eap";
      };
      "802-1x" = {
        eap                = "tls;";
        # Identity is the cert CN (no anonymous identity); its realm routes
        # auth back to the home RADIUS from any eduroam campus.
        identity           = identity;
        client-cert        = "/etc/nixos/certs/eduroam-client.pem";
        private-key        = "/etc/nixos/certs/eduroam-key.pem";
        # Key is unencrypted: tell NM no password is needed (flag 4 =
        # not-required) so it never requests a secret.
        private-key-password-flags = "4";
        # Home RADIUS servers may use different public CAs, so trust the
        # system bundle and pin the server by name (domainSuffixMatch) instead.
        ca-cert            = "/etc/ssl/certs/ca-certificates.crt";
        domain-suffix-match = domainSuffixMatch;
      };
      ipv4 = {
        method = "auto";
      };
      ipv6 = {
        addr-gen-mode = "default";
        method        = "auto";
      };
    };
  };
}
