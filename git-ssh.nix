# =============================================================================
# Git Configuration & SSH Keys
# =============================================================================
#
# Windows-migration files in ~/
#   ~/gh_action_key      – Ed25519 private key for GitHub authentication/actions
#   ~/gh_action_key.pub  – corresponding public key
#   ~/my_public_key.asc  – GPG public key  (OpenPGP / Thunderbird email encryption)
#   ~/my_secret_key.asc  – GPG secret key  (import manually once → see below)
#   ~/revoke.asc         – GPG revocation certificate
#
# This module
#  1. Writes ~/.gitconfig declaratively via activation script (idempotent,
#     delete ~/.gitconfig to re-generate after changes here).
#  2. Copies gh_action_key{,.pub} into ~/.ssh/ with correct permissions.
#  3. Manages the dedicated Git commit-signing key (git_signing_key{,.pub}):
#       – Key was generated once with:
#           ssh-keygen -t ed25519 -C "you@example.com (git-commit-signing)" \
#                      -f ~/.ssh/git_signing_key -N ""
#       – Public key (for GitHub → Settings → SSH keys → "Signing key"):
#           ssh-ed25519 AAAA... you@example.com (git-commit-signing)
#  4. Writes ~/.ssh/config and ~/.ssh/allowed_signers.
#  5. Enables programs.git, GPG agent, and hardens the SSH daemon.
#
# GPG key note
#  The RSA-4096 key (fingerprint shown by `gpg --list-secret-keys --keyid-format LONG`)
#  has capabilities [SC] (primary) + [E] (subkey).  The [E] subkey is used
#  by Thunderbird for OpenPGP email encryption – it is NOT used for Git
#  commit signing (SSH signing is used instead).
#  To import for Thunderbird, run once as your user:
#    iconv -f UTF-16LE -t UTF-8 ~/my_public_key.asc | tail -c +4 | tr -d '\r' \
#      | gpg --import
#    iconv -f UTF-16LE -t UTF-8 ~/my_secret_key.asc | tail -c +4 | tr -d '\r' \
#      | gpg --import
# =============================================================================
{ config, pkgs, lib, ... }:

let
  user     = "nico";
  homeDir  = "/home/${user}";
  sshDir   = "${homeDir}/.ssh";
  keySrc   = homeDir;   # current location of the migrated key files

  # ── Personal identifiers loaded from a gitignored secrets file ────────────
  # Copy secrets/personal.nix.template → secrets/personal.nix and fill in
  # your real values. The file is excluded via .gitignore (secrets/ dir).
  personal = import ./secrets/personal.nix;

  gitEmail         = personal.gitEmail;          # e.g. "you@example.com"
  gitName          = personal.gitName;           # e.g. "YourGitHubUsername"
  gitSigningPubKey = personal.gitSigningPubKey;  # ssh-ed25519 AAAA…
in
{
  # ── Git ────────────────────────────────────────────────────────────────────
  programs.git.enable = true;

  # ── GPG agent (handles OpenPGP for Thunderbird) ────────────────────────────
  programs.gnupg.agent = {
    enable           = true;
    enableSSHSupport = false;   # SSH auth via ssh-agent, not gpg-agent
  };

  # ── SSH daemon ─────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin        = "no";
    };
  };

  # ── Activation: deploy ~/.gitconfig and ~/.ssh/ on every rebuild ───────────
  system.activationScripts.gitAndSshSetup = {
    deps = [ "specialfs" ];
    text = ''
      set -euo pipefail
      HOME_DIR="${homeDir}"
      SSH_DIR="${sshDir}"
      KEY_SRC="${keySrc}"

      # ── ~/.ssh directory ─────────────────────────────────────────────────
      mkdir -p "$SSH_DIR"
      chmod 700 "$SSH_DIR"
      chown ${user}:users "$SSH_DIR"

      # ── allowed_signers file (re-written on every rebuild) ───────────────
      # Git uses this to verify commit signatures made with the SSH signing key.
      SIGNERS="$SSH_DIR/allowed_signers"
      echo "[git-ssh] Writing $SIGNERS"
      printf '%s %s\n' "${gitEmail}" "${gitSigningPubKey}" > "$SIGNERS"
      chown ${user}:users "$SIGNERS"
      chmod 644 "$SIGNERS"

      # ── .gitconfig (re-written on every rebuild) ─────────────────────────
      GIT_CFG="$HOME_DIR/.gitconfig"
      echo "[git-ssh] Writing $GIT_CFG"
      cat > "$GIT_CFG" << GCFG
[user]
  name  = ${gitName}
  email = ${gitEmail}

[core]
  autocrlf = input
  eol      = lf
  editor   = vim

[init]
  defaultBranch = main

[pull]
  rebase = true

[push]
  autoSetupRemote = true

[credential]
  helper = store

# ── SSH commit signing ──────────────────────────────────────────────────────
[user]
  signingkey = ~/.ssh/git_signing_key

[gpg]
  format = ssh

[gpg "ssh"]
  allowedSignersFile = ~/.ssh/allowed_signers

[commit]
  gpgsign = true

[tag]
  gpgsign = true

[alias]
  st  = status
  co  = checkout
  br  = branch
  lg  = log --oneline --graph --decorate --all
GCFG
      chown ${user}:users "$GIT_CFG"
      chmod 644 "$GIT_CFG"

      # ── GitHub Actions key (copy once) ───────────────────────────────────
      PRIV="$SSH_DIR/gh_action_key"
      PUB="$SSH_DIR/gh_action_key.pub"
      if [ -f "$KEY_SRC/gh_action_key" ] && [ ! -f "$PRIV" ]; then
        echo "[git-ssh] Copying gh_action_key -> $SSH_DIR/"
        cp "$KEY_SRC/gh_action_key"     "$PRIV"
        cp "$KEY_SRC/gh_action_key.pub" "$PUB"
        chown ${user}:users "$PRIV" "$PUB"
        chmod 600 "$PRIV"
        chmod 644 "$PUB"
      fi

      # ── Git signing key (write public key, private key stays in ~/.ssh) ──
      SIGN_PUB="$SSH_DIR/git_signing_key.pub"
      echo "[git-ssh] Ensuring $SIGN_PUB"
      printf '%s\n' "${gitSigningPubKey}" > "$SIGN_PUB"
      chown ${user}:users "$SIGN_PUB"
      chmod 644 "$SIGN_PUB"
      # Private key (git_signing_key) was generated once and lives in ~/.ssh/
      # It is NOT managed here to avoid accidental overwrite.

      # ── ~/.ssh/config (re-written on every rebuild) ──────────────────────
      SSH_CFG="$SSH_DIR/config"
      echo "[git-ssh] Writing $SSH_CFG"
      cat > "$SSH_CFG" << 'SCFG'
# GitHub – authentication (push/pull)
Host github.com
  User            git
  IdentityFile    ~/.ssh/gh_action_key
  AddKeysToAgent  yes

# Global defaults
Host *
  ServerAliveInterval 60
  ServerAliveCountMax 3
SCFG
      chown ${user}:users "$SSH_CFG"
      chmod 600 "$SSH_CFG"
    '';
  };
}
