# =============================================================================
# NixOS System Configuration  –  entry point
# =============================================================================
#
# Module layout
# ─────────────
#  configuration.nix   ← you are here (networking, locale, services, state)
#  hardware.nix        ← boot, LUKS, kernel, power, bluetooth, firmware
#  filesystems.nix     ← btrfs subvolume mounts (shared LUKS partition)
#  desktop.nix         ← display manager, DE, audio, printing, input
#  user.nix            ← users.users.nico, user packages, zsh, adb, wireshark
#  git-ssh.nix         ← git config, SSH host config, GPG agent, sshd hardening
#  backup.nix          ← btrbk snapshots + BorgBackup to USB drives
#  xdg-defaults.nix    ← default applications (MIME types, BROWSER/EDITOR vars, xdg-portal)
#
# Help: nixos-help  |  man configuration.nix  |  https://nixos.org/nixos/options.html
# =============================================================================

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix  # auto-generated hardware scan
    ./hardware.nix
    ./filesystems.nix
    ./desktop.nix
    ./user.nix
    ./git-ssh.nix
    ./backup.nix
    ./xdg-defaults.nix
    ./security-auth.nix
  ];

  programs.nix-ld.enable = true;

  # ── Networking ─────────────────────────────────────────────────────────────
  networking.hostName              = "nixos";
  networking.networkmanager.enable  = true;
  networking.networkmanager.plugins = [ pkgs.networkmanager-openconnect ];
  networking.firewall.enable                    = true;
  networking.firewall.logRefusedConnections     = true;  # 26.05: default changed to false

  # ── Locale & Time ──────────────────────────────────────────────────────────
  time.timeZone      = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";

  # ── System Packages ──────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    wget
  ];

  # Only nixos-rebuild still needs sudo – keep that NOPASSWD rule.
  security.sudo.extraRules = [
    {
      users    = [ "nico" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Shell aliases
  programs.zsh.shellAliases = {
    nixos-rebuild = "sudo nixos-rebuild switch";
  };

  # ── Core Programs ──────────────────────────────────────────────────────────
  programs.firefox.enable = true;

  programs.mtr.enable = true;

  # ── Network Discovery (mDNS / .local) ─────────────────────────────────────
  services.avahi = {
    enable       = true;
    nssmdns4     = true;   # lets getaddrinfo() resolve .local hostnames
    openFirewall = true;
  };

  # ── Virtualisation ─────────────────────────────────────────────────────────
  # virtualisation.virtualbox.host.enable = true;
  # virtualisation.virtualbox.host.enableExtensionPack = true;

  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune.enable = true;
  virtualisation.docker.daemon.settings = {
    storage-driver = "btrfs";
  };

  # ── Flatpak ────────────────────────────────────────────────────────────────
  services.flatpak.enable = true;

  # ── Package Policy ─────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;

  # ── NixOS Release Version ──────────────────────────────────────────────────
  # Keep at the release used during initial install. Read the docs before
  # changing: man configuration.nix → system.stateVersion
  system.stateVersion = "25.11"; # Did you read the comment?
}
