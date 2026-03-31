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
#  git-ssh.nix         ← git config, SSH key deployment (from Windows migration)
#  backup.nix          ← btrbk snapshots + BorgBackup to USB drives
#  xdg-defaults.nix    ← default applications (MIME types, BROWSER/EDITOR vars, xdg-portal)
#
# Help: nixos-help  |  man configuration.nix  |  https://nixos.org/nixos/options.html
# =============================================================================

{ config, pkgs, ... }:

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
  ];

  # ── Networking ─────────────────────────────────────────────────────────────
  networking.hostName              = "nixos";
  networking.networkmanager.enable = true;
  # networking.wireless.enable     = true;   # wpa_supplicant alternative
  # networking.proxy.default       = "http://user:password@proxy:port/";
  # networking.proxy.noProxy       = "127.0.0.1,localhost,internal.domain";

  # Firewall (open ports as needed)
  # networking.firewall.allowedTCPPorts = [ 80 443 ];
  # networking.firewall.allowedUDPPorts = [ ];
  # networking.firewall.enable = false;

  # ── Locale & Time ──────────────────────────────────────────────────────────
  time.timeZone      = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT    = "de_DE.UTF-8";
    LC_MONETARY       = "de_DE.UTF-8";
    LC_NAME           = "de_DE.UTF-8";
    LC_NUMERIC        = "de_DE.UTF-8";
    LC_PAPER          = "de_DE.UTF-8";
    LC_TELEPHONE      = "de_DE.UTF-8";
    LC_TIME           = "de_DE.UTF-8";
  };

  # ── System Packages ────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
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

  # ── Virtualisation ─────────────────────────────────────────────────────────
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune.enable = true;
  virtualisation.docker.daemon.settings = {
    storage-driver = "btrfs";
    data-root = "/var/lib/docker/@docker";
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
