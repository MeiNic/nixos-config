# User Account & Login Shell (apps: desktop/apps.nix, development/)
{ pkgs, ... }:

let
  inherit (import ./settings.nix) user;
in
{
  users.users.${user} = {
    isNormalUser = true;
    description  = user;
    initialHashedPassword = "$6$dWIUHsKbON.yT1am$tQOmnIRxNZu6xEMRT2R5QdsCUG8Eo2kcRZVjyG.vdoKNjVz9wJFa3GCyWUPZFxswsQ0V9p1rV1as/4yalBMa8/";
    shell        = pkgs.fish;
    extraGroups  = [ "networkmanager" "wheel" "wireshark" "adbusers" "docker"];
  };

  # Fish must be enabled system-wide so it is a valid login shell.
  programs.fish.enable = true;

  # The login shell is fish (see users.users above), so the nixos-rebuild
  # shortcut is a fish abbreviation.
  programs.fish.shellAbbrs = {
    nixos-rebuild = "sudo nixos-rebuild switch";
  };

  # Fish plugins — added to environment.systemPackages so NixOS places them
  # on the vendor path that fish sources automatically on startup.
  environment.systemPackages = with pkgs; [
    fishPlugins.pure               # minimal git-aware prompt (matches existing fish_variables)
    fishPlugins.autopair           # auto-close brackets/quotes
    fishPlugins.fzf-fish           # fuzzy search history/files/git/processes (Ctrl+R, Ctrl+T)
    fishPlugins.done               # desktop notification when a long command finishes
    fishPlugins.fish-you-should-use # nudges you toward an existing abbreviation/alias
    fishPlugins.sponge             # scrubs failed commands out of history
    fzf                            # backend fzf-fish shells out to
  ];
}
