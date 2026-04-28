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
  # ── Personal identifiers loaded from a gitignored secrets file ────────────
  personal = import ./secrets/personal.nix;

  gitEmail         = personal.gitEmail;
  gitName          = personal.gitName;
  gitSigningPubKey = personal.gitSigningPubKey;
in
{
  # ── Git ────────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    config = {
      user = {
        name  = gitName;
        email = gitEmail;
        signingkey = "~/.ssh/git_signing_key";
      };
      core = {
        autocrlf = "input";
        eol      = "lf";
        editor   = "vim";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      credential.helper = "store";
      gpg = {
        format = "ssh";
        ssh.allowedSignersFile = "/etc/ssh/allowed_signers";
      };
      commit.gpgsign = true;
      tag.gpgsign = true;
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        lg = "log --oneline --graph --decorate --all";
        ci = "commit";
      };
    };
  };

  # ── SSH & Signers ──────────────────────────────────────────────────────────
  programs.ssh.extraConfig = ''
    # GitHub – authentication (push/pull)
    Host github.com
      User            git
      IdentityFile    ~/.ssh/gh_action_key
      AddKeysToAgent  yes

    # Global defaults
    Host *
      ServerAliveInterval 60
      ServerAliveCountMax 3
  '';

  environment.etc."ssh/allowed_signers".text = ''
    ${gitEmail} ${gitSigningPubKey}
  '';

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
}
