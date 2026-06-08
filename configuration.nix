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
    ./eduroam.nix
  ];

  programs.nix-ld.enable = true;

  # ── Networking ─────────────────────────────────────────────────────────────
  networking.hostName              = "nixos";
  networking.networkmanager.enable  = true;
  networking.networkmanager.plugins = [ pkgs.networkmanager-vpnc pkgs.networkmanager-openconnect ];
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

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  # ── Network Discovery (mDNS / .local) ─────────────────────────────────────
  services.avahi = {
    enable       = true;
    nssmdns4     = true;   # lets getaddrinfo() resolve .local hostnames
    openFirewall = true;
  };

  # ── Printing ───────────────────────────────────────────────────────────────
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.gutenprint ];


  # ── Virtualisation ─────────────────────────────────────────────────────────
  # virtualisation.virtualbox.host.enable = true;
  # virtualisation.virtualbox.host.enableExtensionPack = true;


  # Enable Docker daemon and let the container live on the data vg
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings = {
      storage-driver = "btrfs";
      bip = "172.30.0.1/24";
      default-address-pools = [
        { base = "172.30.0.0/16"; size = 24; }
      ];
      data-root = "/data/docker";
      log-driver = "json-file";
      log-opts = {
        max-size = "100m";
        max-file = "10";
      };
      live-restore = true;  # containers keep running if daemon restarts
    };
  };

  # ── Flatpak ────────────────────────────────────────────────────────────────
  services.flatpak.enable = true;

  # ── Package Policy ─────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;

  # ── Generation Management ──────────────────────────────────────────────────
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };


  # ── NixOS Release Version ──────────────────────────────────────────────────
  # Keep at the release used during initial install. Read the docs before
  # changing: man configuration.nix → system.stateVersion
  system.stateVersion = "25.11"; # Did you read the comment?
}
