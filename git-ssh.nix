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
