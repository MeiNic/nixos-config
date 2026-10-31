# =============================================================================
# VS Code + its full extension set
# =============================================================================
# Declared here so a fresh install reproduces the same editor without
# clicking through the marketplace.
{ pkgs, ... }:

{
  # Only VS Code package in this config — do not also add the plain `vscode`
  # package elsewhere, or it would shadow this extension-bundled one on PATH.
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
      drblury.protobuf-vsc
      dotjoshjohnson.xml
      esbenp.prettier-vscode
      fill-labs.dependi
      github.vscode-github-actions
      github.vscode-pull-request-github
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
      myriad-dreamin.tinymist
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
      yzhang.markdown-all-in-one
    ];
  };
}
