{ ... }:

let
  inherit (import ./secrets/eduroam.nix) identity domainSuffixMatch;
in
{
  # wpa_supplicant runs as its own user, so it must own the cert/key files
  # or it gets "Permission denied" loading the key and prompts for a passphrase.
  systemd.tmpfiles.rules = [
    "z /etc/nixos/certs/eduroam-key.pem    0400 wpa_supplicant wpa_supplicant - -"
    "z /etc/nixos/certs/eduroam-client.pem 0444 wpa_supplicant wpa_supplicant - -"
  ];

  networking.networkmanager.ensureProfiles.profiles = {
    eduroam = {
      connection = {
        id          = "eduroam";
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
        eap      = "tls;";
        # The cert CN is used as the identity (no anonymous identity); its
        # realm routes auth back to the home RADIUS from any eduroam campus.
        identity = identity;
        client-cert = "/etc/nixos/certs/eduroam-client.pem";
        private-key = "/etc/nixos/certs/eduroam-key.pem";
        # Flag 4 = not-required: key is unencrypted, NM must not request a
        # secret or the connection fails when no agent is present.
        private-key-password-flags = "4";
        # Home RADIUS servers may use different public CAs (HARICA, Sectigo, …),
        # so trust the system bundle and pin by server name instead.
        ca-cert             = "/etc/ssl/certs/ca-certificates.crt";
        domain-suffix-match = domainSuffixMatch;
      };
      ipv4 = { method = "auto"; };
      ipv6 = { addr-gen-mode = "default"; method = "auto"; };
    };
  };
}
