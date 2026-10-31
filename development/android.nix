# =============================================================================
# Flutter / Android: toolchain + SDK/emulator environment
# =============================================================================
# Lets Flutter target the emulator from VS Code without ever opening Android
# Studio again.
{ pkgs, ... }:

let
  inherit (import ../settings.nix) user;
in
{
  users.users.${user}.packages = with pkgs; [
    dart
    flutter
    android-studio
    android-tools
  ];

  # ── Android SDK / emulator ──────────────────────────────────────────────────
  # The SDK at ~/Android/Sdk (platform-tools, emulator, system images, and the
  # "Medium_Phone_API_36.1" AVD) was already provisioned by Android Studio.
  # use in commandline with "emulator -avd Medium_Phone_API_36.1" or "flutter emulators --launch Medium_Phone_API_36.1"
  #
  # cmdline-tools (sdkmanager/avdmanager/apkanalyzer) is NOT nix-managed here:
  # nixpkgs' androidenv wrapper hardcodes its own --sdk_root into the nix
  # store, ignoring $ANDROID_HOME, so it can't be pointed at this externally
  # (Android-Studio-)managed SDK. It was instead extracted for real from the
  # same official zip nixpkgs fetches (see chat history 2026-09-06) directly
  # into ~/Android/Sdk/cmdline-tools/latest — plain mutable files, imperatively
  # managed like the rest of this SDK.
  environment.sessionVariables = {
    ANDROID_HOME     = "$HOME/Android/Sdk";
    ANDROID_SDK_ROOT = "$HOME/Android/Sdk";
    PATH = [
      "$HOME/Android/Sdk/cmdline-tools/latest/bin"  # sdkmanager/avdmanager
      "$HOME/Android/Sdk/platform-tools"             # adb (SDK-matched version takes priority over android-tools)
      "$HOME/Android/Sdk/emulator"                   # emulator
    ];
  };

  environment.systemPackages = [
    pkgs.mesa-demos  # eglinfo/glxinfo — silences flutter doctor's Linux toolchain warning
  ];

  programs.nix-ld.libraries = with pkgs; [
    libx11
    libxext
    libxcb
  ];
}
