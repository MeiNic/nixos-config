# Commands

## Configuration management

```bash
sudo nixos-rebuild build       # Evaluate + build only — validate a change
sudo nixos-rebuild test        # Activate without making it the default boot entry
sudo nixos-rebuild switch      # Activate and make it the boot default (fish abbreviation: nixos-rebuild)
sudo nixos-rebuild boot        # Make it the boot default without activating now (kernel/initrd/microcode changes)
```

## Updates and maintenance

```bash
# Update all channels (nixos + nixos-unstable) and rebuild in one step
sudo nixos-rebuild switch --upgrade-all

# Clean up old generations and free disk space
sudo nix-collect-garbage -d

# List generations / roll back
sudo nixos-rebuild list-generations
sudo nixos-rebuild switch --rollback

# Versions & health
nixos-version
nix --version
systemctl --failed
```

## Pinned versions

```bash
# sops-nix (security/secrets.nix): take master's head, then put the rev + hash into the url/sha256
git ls-remote https://github.com/Mic92/sops-nix refs/heads/master
nix-prefetch-url --unpack https://github.com/Mic92/sops-nix/archive/<rev>.tar.gz

# open-android-backup (backup/android.nix): only on a new upstream release tag.
# Update rev + version, set hash = "" and rebuild to get the real hash from the error;
# the build fails if backup/open-android-backup-nixos-unattended-fixes.patch no longer applies.
sudo systemctl start android-backup-auto   # test with the phone connected
```

## Backup and snapshots

```bash
backup-status                      # Overview: timers, btrbk snapshots, offsite + USB Borg state

# btrbk snapshots (hourly)
ls /.snapshots
systemctl list-timers btrbk.timer
sudo journalctl -u btrbk -n 50

# Android → Hetzner Storage Box (auto-fires on USB connect; run manually for contacts)
sudo systemctl start android-backup-manual
sudo journalctl -fu android-backup-auto
```

## System information

```bash
# Hardware
hardinfo2                          # Detailed hardware information
fastfetch                          # System summary
lsblk                              # Disk/partition layout
duf                                # Disk usage per mount
sensors                            # CPU/thermal sensors
sudo dmidecode -t bios             # BIOS/UEFI info
nix-shell -p smartmontools --run 'sudo smartctl -a /dev/nvme0n1'   # NVMe health

# Audio (PipeWire)
wpctl status                       # Sinks, sources, streams
journalctl --user -u pipewire -n 50

# Battery
cat /sys/class/power_supply/BAT1/status
cat /sys/class/power_supply/BAT1/capacity
```

## Security and authentication

```bash
# Account lockout (lock screen)
faillock --user nico               # Check lock status
faillock --user nico --reset       # Unlock (sudo still works via YubiKey)
# Emergency access: Ctrl+Alt+F2 → login: nico → password, then the reset above

# YubiKey
ykman list                         # Is the key detected?
systemctl status pcscd             # Smart-card daemon

# Fingerprint reader
fprintd-verify                     # Interactive fingerprint test
```

## Default applications

```bash
# Find the correct .desktop ID
find /run/current-system/sw/share/applications /etc/profiles/per-user/$USER/share/applications ~/.local/share/applications -name '*.desktop' | sort
# Check what's currently registered for a type:
xdg-mime query default application/pdf
```

## GPG key import

```bash
# Once, for Thunderbird OpenPGP
iconv -f UTF-16LE -t UTF-8 ~/my_public_key.asc | tail -c +4 | tr -d '\r' | gpg --import
iconv -f UTF-16LE -t UTF-8 ~/my_secret_key.asc | tail -c +4 | tr -d '\r' | gpg --import
```

## Borg offsite setup

```bash
# 1. Generate a dedicated key (private key never leaves a scratch dir)
ssh-keygen -t ed25519 -N '' -C nixos-offsite-backup -f /tmp/offsite_backup_key

# 2. Install the public key on the sub-account (prompts for its password once),
#    after pinning the host key - see the checks in the setup script
cat /tmp/offsite_backup_key.pub | ssh -p23 <sub-account>@<sub-account>.your-storagebox.de install-ssh-key

# 3. Store key + a generated passphrase in secrets.yaml (see § Secrets for the sudo env wrapper):
#    '["offsite-backup-ssh-key"]' and '["offsite-backup-passphrase"]'
# 4. Save the passphrase in a password manager - with a lost laptop it is the only thing
#    you need besides the sub-account password (the age key and secrets are IN the backup)
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops -d --extract '["offsite-backup-passphrase"]' /etc/nixos/secrets.yaml

# 5. sudo nixos-rebuild switch - the first run starts at the next tick once on AC + ethernet
```

## Borg key export

```bash
# Storage Box
sudo bash -c 'export BORG_REMOTE_PATH=borg-1.4 BORG_RSH="ssh -i /run/secrets/offsite-backup-ssh-key -o IdentitiesOnly=yes -o UserKnownHostsFile=/etc/nixos/secrets/hetzner-storagebox-known_hosts"; borg key export --paper ssh://<sub-account>@<sub-account>.your-storagebox.de:23/./borg-repo'

# USB drive (connected)
sudo mount /dev/disk/by-uuid/246f76d5-4bfd-48d6-8ada-e8c131709ba6 /mnt/backup-hdd
sudo borg key export --paper /mnt/backup-hdd/borg-repo
sudo umount /mnt/backup-hdd
```

## Borg daily use

```bash
backup-status                                 # per job: last success, running/unfinished run, last check; power/ethernet/drive state
sudo systemctl start offsite-backup           # run now (still needs its conditions and >24 h since last success)
sudo systemctl start usb-backup               #   same for the USB drive
sudo rm /var/lib/offsite-backup/last-success  # force the next start to run a fresh backup (same for usb-backup)
journalctl -fu offsite-backup                 # or usb-backup

# Browse / restore from the Storage Box (root shell so the sops secrets are readable)
sudo -i
export BORG_REMOTE_PATH=borg-1.4 BORG_PASSCOMMAND='cat /run/secrets/offsite-backup-passphrase'
export BORG_RSH='ssh -i /run/secrets/offsite-backup-ssh-key -o IdentitiesOnly=yes -o UserKnownHostsFile=/etc/nixos/secrets/hetzner-storagebox-known_hosts'
REPO=ssh://<sub-account>@<sub-account>.your-storagebox.de:23/./borg-repo
borg list $REPO
borg extract $REPO::<archive> home/nico/Documents/some/file     # paths have no leading slash
borg mount $REPO::<archive> /mnt                                # needs fuse; umount when done

# Browse / restore from the USB drive - mount it at the job's own mount point;
# a running usb-backup then uses that mount and leaves it alone
sudo -i
mount /dev/disk/by-uuid/246f76d5-4bfd-48d6-8ada-e8c131709ba6 /mnt/backup-hdd
export BORG_PASSCOMMAND='cat /run/secrets/offsite-backup-passphrase'
borg list /mnt/backup-hdd/borg-repo
borg extract /mnt/backup-hdd/borg-repo::<archive> home/nico/Documents/some/file
umount /mnt/backup-hdd
```

## Android backup setup

```bash
# <android-sub-account> = androidStorageBoxUser in secrets/personal.nix

# 1. Generate a dedicated SSH keypair
ssh-keygen -t ed25519 -f /tmp/hetzner-storagebox -C "android-backup@nixos"

# 2. Install the public key on the sub-account via Hetzner's built-in command
#    (prompts for the sub-account's password once)
cat /tmp/hetzner-storagebox.pub | ssh -p23 <android-sub-account>@<android-sub-account>.your-storagebox.de install-ssh-key

# 3. Put the private key into secrets.yaml (see § Secrets for why the sudo
#    env wrapper is needed) and drop the local copies
cd /etc/nixos
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops set secrets.yaml \
  '["hetzner-storagebox-key"]' "$(cat /tmp/hetzner-storagebox | nix-shell -p jq --run 'jq -Rs .')"
rm /tmp/hetzner-storagebox /tmp/hetzner-storagebox.pub

# 4. Pin the SFTP host key (verify the fingerprint against Robot's panel!)
#    Not a secret - stays a plain file, unlike the key above.
ssh-keyscan -p 23 <android-sub-account>.your-storagebox.de | sudo tee /etc/nixos/secrets/hetzner-storagebox-known_hosts
sudo chown root:root /etc/nixos/secrets/hetzner-storagebox-known_hosts
sudo chmod 600 /etc/nixos/secrets/hetzner-storagebox-known_hosts

# 5. Set the archive password
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops set secrets.yaml \
  '["android-backup-env"]' "$(printf 'archive_password=%s' 'your-strong-passphrase' | nix-shell -p jq --run 'jq -Rs .')"
```

## Android backup

```bash
# Trigger the full backup (incl. contacts) manually
sudo systemctl start android-backup-manual

# Watch it run
sudo journalctl -fu android-backup-auto
sudo journalctl -fu android-backup-manual

# List what's currently on the Storage Box
sudo rclone lsf ":sftp:android-backup" --sftp-host <android-sub-account>.your-storagebox.de \
  --sftp-port 23 --sftp-user <android-sub-account> \
  --sftp-key-file /run/secrets/hetzner-storagebox-key \
  --sftp-known-hosts-file /etc/nixos/secrets/hetzner-storagebox-known_hosts \
  --sftp-shell-type unix
```

## Secrets

```bash
# Interactive (decrypts to $EDITOR, re-encrypts on save) - simplest for one-off edits
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops secrets.yaml

# Scripted / from a file, preserving exact byte content (multi-line keys etc.)
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops set secrets.yaml \
  '["secret-name"]' "$(sudo cat /path/to/file | nix-shell -p jq --run 'jq -Rs .')"
```

## YubiKey PIV enrollment

```bash
# Provision each key in turn (plug in only one at a time)
ykman piv access change-management-key --generate --protect  # replace factory default
ykman piv access change-pin        # default 123456 → yours (6–8 digits)
ykman piv access change-puk        # default 12345678 → yours
ykman piv keys generate --algorithm eccp384 9a ~/piv-pub.pem
ykman piv certificates generate --subject "CN=nico-piv-<name>" 9a ~/piv-pub.pem
mkdir -p ~/.eid && chmod 700 ~/.eid
ykman piv certificates export 9a - >> ~/.eid/authorized_certificates   # APPEND — one block per key
chmod 600 ~/.eid/authorized_certificates && rm ~/piv-pub.pem
```

## YubiKey U2F enrollment

```bash
pamu2fcfg -n   # -n if u2f-mappings already has a key in it, otherwise omit
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops secrets.yaml   # append the line above under u2f-mappings, save
```

## eduroam setup

```bash
# 2. Extract cert and key from the .p12 into certs/ (gitignored)
mkdir -p /etc/nixos/certs

# Public client certificate
openssl pkcs12 -legacy -in YOUR.p12 -clcerts -nokeys -passin pass: \
  | openssl x509 -out /etc/nixos/certs/eduroam-client.pem

# Unencrypted private key (mode 400, owned by wpa_supplicant via tmpfiles)
openssl pkcs12 -legacy -in YOUR.p12 -nocerts -nodes -passin pass: \
  | openssl pkey -out /etc/nixos/certs/eduroam-key.pem

# 3. Fill in your secrets
cp secrets/eduroam.nix.template secrets/eduroam.nix
openssl x509 -in certs/eduroam-client.pem -noout -subject   # identity: the CN from your cert
journalctl -u wpa_supplicant | grep 'PEER-CERT depth=0'     # domainSuffixMatch: server name(s) your supplicant sees

# 4. Rebuild
sudo nixos-rebuild switch
```

## Affinity setup

```bash
# 1. Create and configure the wine prefix
affinity-setup                 # Takes 10-20 min (downloads .NET 4.8)

# 2. Download the installer into ~/wine/affinity (keeps it out of ~/Downloads)
# Affinity by Canva: https://www.affinity.studio/download
# Affinity v2: https://affinity.serif.com/v2/
mkdir -p ~/wine/affinity
WINEPREFIX=$HOME/.affinity wine ~/wine/affinity/'Affinity x64.exe'

# 3. For Affinity by Canva only — apply the WineFix (patches sign-in + prefs saving)
affinity-winefix

# 4. Install DXVK — Wine's built-in D3D has no working D3D12 path, which shows up
#    as blank white/black context menus and popups. DXVK routes D3D through Vulkan
#    (works with the Intel Arc/Meteor Lake iGPU) and fixes it.
WINEPREFIX=$HOME/.affinity winetricks --unattended dxvk renderer=vulkan

# 5. Launch
affinity                       # Launches Affinity by Canva
```

## Affinity display scaling

```bash
affinity-scale 135             # 135% scale → 130 DPI
affinity-scale 150             # 150% scale → 144 DPI
```
