# =============================================================================
# Secrets management: sops-nix (age)
# =============================================================================
# Replaces the old ad-hoc mix of plain-text runtime files under secrets/ for
# actual secrets (passphrases, keys) with one encrypted, git-tracked file:
# secrets.yaml. Values needed at Nix eval time (personal.nix, eduroam.nix,
# luks-uuids.nix - none of them true secrets, or needed before sops can even
# run) stay as plain imported files; sops-nix only produces runtime file
# paths (/run/secrets/*), decrypted during system activation.
{ config, pkgs, lib, ... }:

let
  # builtins.fetchTarball, not pkgs.fetchFromGitHub: `imports` is resolved
  # before the module system's own `pkgs` argument is settled, so depending
  # on `pkgs` here causes infinite recursion. This fetcher is a pure builtin.
  sopsNixSrc = builtins.fetchTarball {
    url    = "https://github.com/Mic92/sops-nix/archive/a8627b21b9107c5711c96b84f32a9a4b3d45295f.tar.gz";
    sha256 = "1j89yslxj0q29xzrjcp19r4a130k4cdihx4yw6f2bm72fgia0j42";
  };
in
{
  imports = [ "${sopsNixSrc}/modules/sops" ];

  environment.systemPackages = [ pkgs.sops pkgs.age ];

  sops.defaultSopsFile = ./secrets.yaml;
  # age (X25519 + ChaCha20-Poly1305) - modern primitives, far smaller attack
  # surface than GPG. sops itself always uses AES256-GCM for the values
  # regardless of key backend; age is what protects the wrapping key.
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # Default owner/mode (root:root, 0400) suits everything except
  # u2f-mappings, which PAM needs to read outside a pure root context.
  sops.secrets.u2f-mappings = {
    owner = "root";
    mode  = "0444";
  };
  sops.secrets.android-backup-env = { };
  sops.secrets.hetzner-storagebox-key = { };
}
