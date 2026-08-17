# =============================================================================
# Development Tooling: VSCode + Android/Flutter
# =============================================================================
# VSCode itself, plus the whole extension set, is declared here so a fresh
# install reproduces the same editor without clicking through the
# marketplace. The Android bits let Flutter target the emulator from VSCode
# without ever opening Android Studio again.
{ pkgs, ... }:

{
  # ── Android SDK / emulator ──────────────────────────────────────────────────
  # The SDK at ~/Android/Sdk (platform-tools, emulator, system images, and the
  # "Medium_Phone_API_36.1" AVD) was already provisioned by Android Studio.
  # use in commandline with "emulator -avd Medium_Phone_API_36.1" or "flutter emulators --launch Medium_Phone_API_36.1"
  environment.sessionVariables = {
    ANDROID_HOME     = "$HOME/Android/Sdk";
    ANDROID_SDK_ROOT = "$HOME/Android/Sdk";
    PATH = [
      "$HOME/Android/Sdk/cmdline-tools/latest/bin"  # sdkmanager/avdmanager, if installed later
      "$HOME/Android/Sdk/platform-tools"             # adb (SDK-matched version takes priority over android-tools)
      "$HOME/Android/Sdk/emulator"                   # emulator
    ];
  };


  programs.nix-ld.libraries = with pkgs; [
    libx11
    libxext
    libxcb
  ];

  # ── VSCode ───────────────────────────────────────────────────────────────────
  # Replaces the plain `vscode` package that used to live in user.nix — keep
  # them from both being installed, or the plain one (earlier on PATH) would
  # shadow this extension-bundled one.
  #
  # Extension set mirrors what was actually installed via the marketplace
  # (`code --list-extensions`) on 2026-08-08. The following are NOT packaged
  # in nixpkgs' vscode-extensions set and still need `code --install-extension
  # <id>` by hand after a fresh install:
  #   1yib.rust-bundle, bruno-api-client.bruno, dustypomerleau.rust-syntax,
  #   johnpapa.angular-essentials, johnpapa.angular2, lenagain.latexindent,
  #   mermaidchart.vscode-mermaid-chart, ms-playwright.playwright,
  #   ms-vscode.cpp-devtools, ms-vscode.cpptools-themes,
  #   ms-vscode.vscode-typescript-next, sankethdev.vscode-proto,
  #   uctakeoff.vscode-counter
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      adpyke.codesnap
      angular.ng-template
      anthropic.claude-code
      arjun.swagger-viewer
      bbenoist.nix
      bradlc.vscode-tailwindcss
      christian-kohler.path-intellisense
      dart-code.dart-code
      dart-code.flutter
      davidanson.vscode-markdownlint
      dbaeumer.vscode-eslint
      docker.docker
      dotjoshjohnson.xml
      esbenp.prettier-vscode
      fill-labs.dependi
      github.vscode-github-actions
      gitlab.gitlab-workflow
      gruntfuggly.todo-tree
      hediet.vscode-drawio
      james-yu.latex-workshop
      johnpapa.winteriscoming
      mechatroner.rainbow-csv
      ms-azuretools.vscode-containers
      ms-azuretools.vscode-docker
      ms-python.debugpy
      ms-python.python
      ms-python.vscode-pylance
      ms-python.vscode-python-envs
      ms-toolsai.jupyter
      ms-toolsai.jupyter-keymap
      ms-toolsai.jupyter-renderers
      ms-toolsai.vscode-jupyter-cell-tags
      ms-toolsai.vscode-jupyter-slideshow
      ms-vscode.cmake-tools
      ms-vscode.cpptools
      ms-vscode.cpptools-extension-pack
      ms-vscode.powershell
      ms-vsliveshare.vsliveshare
      pkief.material-icon-theme
      redhat.java
      redhat.vscode-yaml
      rust-lang.rust-analyzer
      twxs.cmake
      valentjn.vscode-ltex
      vscjava.vscode-gradle
      vscjava.vscode-java-debug
      vscjava.vscode-java-dependency
      vscjava.vscode-java-pack
      vscjava.vscode-java-test
      vscjava.vscode-maven
    ];
  };
}
