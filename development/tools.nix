# =============================================================================
# Development: languages, toolchains, CLI tools, Docker, network analysis
# =============================================================================
# Editor: vscode.nix. Flutter/Android: android.nix. Git: security/git-ssh.nix.
{ pkgs, ... }:

let
  inherit (import ../settings.nix) user;
in
{
  users.users.${user}.packages = with pkgs; [
    gh
    go
    jdk21
    nodejs
    pnpm
    python3
    rustup
    gcc
    php
    tokei
    cmake
    ninja
    pkg-config
    gtk3
    clang
    claude-code
    grpc-tools
    zig                # Zig toolchain (compiler + build system)
  ];

  environment.sessionVariables.PATH = [
    "$HOME/.cargo/bin"   # cargo-installed binaries (ccusage)
  ];

  # ── Network Analysis ───────────────────────────────────────────────────────
  programs.mtr.enable = true;

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  # ── Docker ─────────────────────────────────────────────────────────────────
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings = {
      storage-driver = "btrfs";
      bip = "172.30.0.1/24";
      default-address-pools = [
        { base = "172.30.0.0/16"; size = 24; }
      ];
      data-root = "/var/lib/docker";
      log-driver = "json-file";
      log-opts = {
        max-size = "100m";
        max-file = "10";
      };
      live-restore = true;
    };
  };
}
