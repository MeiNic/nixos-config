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
#  1. Writes /etc/gitconfig declaratively (programs.git.config).
#  2. Writes /etc/ssh/ssh_config extras (GitHub host, keepalive).
#  3. Writes /etc/ssh/allowed_signers for SSH commit-signing verification.
#  4. Enables GPG agent (for Thunderbird OpenPGP) and hardens sshd.
#
# Keys that must be placed manually in ~/.ssh/ (not managed by Nix):
#   gh_action_key{,.pub}   – GitHub push/pull auth
#   git_signing_key{,.pub} – Git commit signing (add .pub to GitHub → SSH keys → Signing)
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
{ pkgs, ... }:

let
  inherit (import ./secrets/personal.nix) gitEmail gitName gitSigningPubKey;
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

  # ── GPG agent (handles OpenPGP for Thunderbird; SSH auth stays with ssh-agent)
  programs.gnupg.agent.enable = true;

  # ── SSH daemon ─────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin        = "no";
    };
  };
}
