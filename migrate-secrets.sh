#!/usr/bin/env bash
# One-time migration: encrypts the existing plain-text secrets under
# secrets/ into secrets.yaml. Safe to re-run (each `sops set` overwrites
# only that key). Delete this script once you've confirmed everything works.
set -euo pipefail
cd /etc/nixos

# The `sops` CLI's own key lookup (~/.config/sops/age/keys.txt by default)
# is independent of the sops.age.keyFile NixOS option, which only governs
# decryption during system activation. Our only private key lives at the
# root-owned path below, so any operation that needs to *decrypt* (like
# `sops set`) has to run as root with this pointed at explicitly.
AGE_KEY_FILE=/var/lib/sops-nix/key.txt

if [ ! -f secrets.yaml ]; then
  echo "Creating empty secrets.yaml..."
  # Plain --encrypt (no --in-place): only needs the public key from
  # .sops.yaml, no decryption involved, so no root needed for this part.
  echo '{}' > secrets.yaml
  sops --encrypt --input-type json --output-type yaml secrets.yaml > secrets.yaml.new
  mv secrets.yaml.new secrets.yaml
fi

migrate() {
  local sops_key="$1" src_path="$2"
  if [ -f "$src_path" ]; then
    /run/wrappers/bin/sudo env SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops set secrets.yaml \
      "[\"$sops_key\"]" "$(/run/wrappers/bin/sudo cat "$src_path" | nix-shell -p jq --run 'jq -Rs .')"
    echo "Migrated $sops_key from $src_path"
  else
    echo "Skipping $sops_key - $src_path not found (not set up yet)"
  fi
}

migrate u2f-mappings           /etc/nixos/secrets/u2f-mappings
migrate android-backup-env     /etc/nixos/secrets/android-backup.env
migrate hetzner-storagebox-key /etc/nixos/secrets/hetzner-storagebox.key

echo ""
echo "Done. Verify with: /run/wrappers/bin/sudo env SOPS_AGE_KEY_FILE=$AGE_KEY_FILE sops -d secrets.yaml"
