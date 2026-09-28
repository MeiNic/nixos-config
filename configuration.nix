{ pkgs, ... }:

let
  # Pin for the joplin-desktop overlay below: nixos-26.05 (stable) doesn't
  # backport app version bumps, only security/critical fixes, so it stays on
  # whatever version was current at branch-off (3.5.13). Bump this commit
  # periodically to track newer nixos-unstable releases of Joplin.
  unstableForJoplin = builtins.fetchTarball {
    url    = "https://github.com/NixOS/nixpkgs/archive/20b1ddd1aa5ace70c9468305030aa4f9ef79671b.tar.gz";
    sha256 = "17c8rash8751zwzq426b54754znickr50nwd4ziq4pklm0pid3h7";
  };
  # For claude-code (CLI + VS Code extension) below: tracks whatever is
  # current on the nixos-unstable channel, unlike unstableForJoplin's fixed
  # commit pin. Requires the channel to actually be added on this machine:
  #   sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos-unstable
  #   sudo nix-channel --update
  # then `sudo nix-channel --update` again whenever a newer claude-code is wanted.
  nixosUnstable = <nixos-unstable>;
in
{
  imports = [
    ./hardware-configuration.nix  # auto-generated hardware scan
    ./secrets.nix
    ./hardware.nix
    ./filesystems.nix
    ./desktop.nix
    ./user.nix
    ./git-ssh.nix
    ./backup.nix
    ./android-backup.nix
    ./xdg-defaults.nix
    ./security-auth.nix
    ./eduroam.nix
    ./affinity.nix
    ./rclone-onedrive.nix
    ./development.nix
  ];

  programs.nix-ld.enable = true;

  # ── Overlays ───────────────────────────────────────────────────────────────
  # paho-mqtt 2.1.0's test suite is flaky/broken inside the Nix build sandbox
  # (ConnectionResetError + callback-ordering assertion failures), blocking
  # borgmatic -> apprise -> paho-mqtt. Known upstream issue, no fix yet:
  # https://discourse.nixos.org/t/unable-to-upgrade-to-25-05-because-paho-mqtt/64709
  nixpkgs.overlays = [
    (final: prev: {
      python3 = prev.python3.override {
        packageOverrides = pyFinal: pyPrev: {
          paho-mqtt = pyPrev.paho-mqtt.overridePythonAttrs (_: {
            doCheck = false;
          });
        };
      };
    })
    # joplin-desktop: stable channel is stuck on 3.5.13 (see unstableForJoplin
    # above); pull just this package from nixos-unstable instead.
    (final: prev: {
      joplin-desktop = (import unstableForJoplin { system = prev.stdenv.hostPlatform.system; }).joplin-desktop;
    })
    # claude-code CLI (user.nix) and its VS Code extension (development.nix):
    # both move fast enough that the stable channel lags noticeably, so pull
    # both from the nixos-unstable channel (see nixosUnstable above).
    (final: prev:
      let
        pkgsUnstable = import nixosUnstable {
          system = prev.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        };
      in {
        claude-code = pkgsUnstable.claude-code;
        vscode-extensions = prev.vscode-extensions // {
          anthropic = (prev.vscode-extensions.anthropic or { }) // {
            claude-code = pkgsUnstable.vscode-extensions.anthropic.claude-code;
          };
        };
      })
  ];

  # ── Networking ─────────────────────────────────────────────────────────────
  networking.hostName              = "nixos";
  networking.networkmanager.enable  = true;
  networking.networkmanager.plugins = [ pkgs.networkmanager-openconnect ];
  networking.firewall.enable                    = true;
  networking.firewall.logRefusedConnections     = true;

  # ── Locale & Time ──────────────────────────────────────────────────────────
  time.timeZone      = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";

  # ── System Packages ──────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    wget
  ];

  # ── Sudo Configuration ────────────────────────────────────────────────────────
  security.sudo.enable = true;
  security.sudo.execWheelOnly = false;

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
  services.printing.drivers = [
    pkgs.gutenprint
    pkgs.mfcj470dwlpr           # Brother MFC-J470DW LPR driver (compatible with J497DW)
    pkgs.mfcj470dw-cupswrapper  # CUPS wrapper for the above
  ];


  # ── Virtualisation ─────────────────────────────────────────────────────────
  # Docker's data-root lives on the data vg, not the root filesystem.
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
