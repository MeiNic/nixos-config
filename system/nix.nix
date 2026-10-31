# =============================================================================
# Nix Itself: package policy, unstable overlay, garbage collection, nix-ld
# =============================================================================
{ ... }:

let
  nixosUnstable = <nixos-unstable>;
in
{
  # ── Package Policy ─────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;

  # ── Overlays ───────────────────────────────────────────────────────────────
  nixpkgs.overlays = [
    # Pulled from the nixos-unstable channel (see nixosUnstable above):
    # - claude-code CLI (development/tools.nix) and its VS Code extension
    #   (development/vscode.nix): both move fast enough that the stable channel
    #   lags noticeably.
    # - joplin-desktop: nixos-26.05 doesn't backport app version bumps, only
    #   security/critical fixes, so stable is stuck on 3.5.13 from branch-off.
    #   Drop it from here once the stable channel catches up.
    # - zotero: stable's 9.0.6 is built on a Firefox ESR that Zotero 9 wasn't
    #   updated for; indexing a stored HTML attachment hits "Illegal load attempt
    #   of blob: URL from web" and segfaults the parent (NixOS/nixpkgs#561292).
    #   Fixed in 10.0.2+. Drop it from here once stable ships Zotero 10.
    (final: prev:
      let
        pkgsUnstable = import nixosUnstable {
          system = prev.stdenv.hostPlatform.system;
          config.allowUnfree = true;
          # Zotero 10 embeds Firefox ESR 140, EOL since 2026-10-13. Scoped to this
          # one package and to the unstable import only.
          config.permittedInsecurePackages = [
            "firefox-esr-140-bin-unwrapped-140.17.0esr"
          ];
        };
      in {
        claude-code = pkgsUnstable.claude-code;
        joplin-desktop = pkgsUnstable.joplin-desktop;
        zotero = pkgsUnstable.zotero;
        vscode-extensions = prev.vscode-extensions // {
          anthropic = (prev.vscode-extensions.anthropic or { }) // {
            claude-code = pkgsUnstable.vscode-extensions.anthropic.claude-code;
          };
        };
      })
  ];

  # ── Generation Management ──────────────────────────────────────────────────
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ── nix-ld ─────────────────────────────────────────────────────────────────
  # Runs unpatched prebuilt binaries (Android SDK tools, rustup toolchains, …).
  # Extra libraries are added next to what needs them (development/android.nix).
  programs.nix-ld.enable = true;
}
