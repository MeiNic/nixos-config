# =============================================================================
# Affinity via Wine — "Affinity by Canva" (3.x) and Affinity v2
# =============================================================================
# Method from https://affinity.liz.pet/ and
# https://github.com/seapear/AffinityOnLinux (Guides/Wine/Guide.md).
#
# Requires Wine >= 10.17. We use wineWow64Packages.stable (11.0): being >= 11
# it already ships WinRT metadata support (WineHQ MR #8367), so the old
# Windows.winmd + wintypes.dll shim and library override are NOT needed.
#
# A wine prefix is mutable user state (it downloads .NET etc.), so it can't be
# built declaratively. These wrappers pin the exact wine/winetricks and make
# the imperative one-time setup reproducible:
#   1. affinity-setup            → create prefix + install runtime deps
#   2. wine <installer>.exe       → run the installer (Affinity by Canva is one
#                                   "Affinity x64.exe"; v2 has a separate exe
#                                   per app — run each once)
#   3. affinity-winefix          → required for Affinity by Canva: skips the
#                                   broken Canva sign-in + fixes prefs saving
#   4. affinity                   → launch (defaults to the Canva unified app;
#                                   pass Photo|Designer|Publisher for v2)
{ pkgs, ... }:

let
  wine = pkgs.wineWow64Packages.stable;

  # Tools winetricks shells out to, pinned so the wrappers don't depend on PATH.
  runtimeDeps = [ wine pkgs.winetricks pkgs.curl pkgs.cabextract pkgs.p7zip ];

  affinity-setup = pkgs.writeShellScriptBin "affinity-setup" ''
    set -euo pipefail
    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"
    export WINEPREFIX="''${WINEPREFIX:-$HOME/.affinity}"
    export WINE="$(command -v wine)"
    export WINEARCH=win64

    echo ">> Creating prefix at $WINEPREFIX (wine ${wine.version})"
    # Disable mscoree (Mono) and mshtml (Gecko) for init so Wine doesn't pop the
    # "wine-mono is not installed" dialog — we remove Mono and use real .NET 4.8.
    WINEDLLOVERRIDES="mscoree=d;mshtml=d" wineboot --init
    wineserver -w   # wait for the prefix to settle before winetricks

    echo ">> Installing runtime dependencies (dotnet48 takes 10-20 min)…"
    winetricks --unattended --force remove_mono vcrun2022 dotnet48 corefonts win11

    cat <<'EOF'

>> Dependencies installed. Next:
   1. Download the installer into ~/Downloads:
        Affinity by Canva (free, 3.x):  https://www.affinity.studio/download
        Affinity v2 (existing license): https://affinity.serif.com/v2/
   2. Run the installer, e.g.:
        WINEPREFIX=$HOME/.affinity wine ~/Downloads/'Affinity x64.exe'
      (for v2, run each app's installer once)
   3. Affinity by Canva only — apply the sign-in/prefs fix:
        affinity-winefix
   4. Launch:
        affinity                 # Affinity by Canva (unified app)
        affinity Photo           # v2 (or Designer / Publisher)

   Optional, if you hit rendering glitches:
        WINEPREFIX=$HOME/.affinity winetricks dxvk renderer=vulkan
EOF
  '';

  # AffinityPluginLoader + WineFix (https://github.com/noahc3/AffinityPluginLoader)
  # Required for "Affinity by Canva": skips the broken Canva sign-in dialog and
  # restores on-the-fly settings saving. Re-run after an Affinity update, which
  # overwrites Affinity.exe.
  affinity-winefix = pkgs.writeShellScriptBin "affinity-winefix" ''
    set -euo pipefail
    export PATH="${pkgs.lib.makeBinPath [ pkgs.curl pkgs.gnutar pkgs.xz ]}:$PATH"
    export WINEPREFIX="''${WINEPREFIX:-$HOME/.affinity}"
    dir="$WINEPREFIX/drive_c/Program Files/Affinity/Affinity"

    if [ ! -f "$dir/Affinity.exe" ]; then
      echo "Affinity by Canva not found at $dir — install it first." >&2
      exit 1
    fi

    echo ">> Downloading AffinityPluginLoader + WineFix…"
    curl -L -o /tmp/aplwf.tar.xz \
      https://github.com/noahc3/AffinityPluginLoader/releases/latest/download/affinitypluginloader-plus-winefix.tar.xz
    tar -xf /tmp/aplwf.tar.xz -C "$dir"

    # Swap the real launcher for the hook (idempotent: keep the original backup).
    if [ ! -f "$dir/Affinity.real.exe" ]; then
      mv "$dir/Affinity.exe" "$dir/Affinity.real.exe"
    fi
    mv "$dir/AffinityHook.exe" "$dir/Affinity.exe"
    echo ">> WineFix applied. Launch with: affinity"
  '';

  # Wine has no per-monitor scaling on X11/XWayland and doesn't read the KDE
  # scale; it uses one DPI per prefix. Set it to 96 × your Plasma scale, e.g.
  #   affinity-scale 135   → 130 DPI   (matches a 1.35 display)
  #   affinity-scale 170   → 163 DPI   (matches a 1.7 display)
  affinity-scale = pkgs.writeShellScriptBin "affinity-scale" ''
    set -euo pipefail
    export PATH="${pkgs.lib.makeBinPath [ wine ]}:$PATH"
    export WINEPREFIX="''${WINEPREFIX:-$HOME/.affinity}"

    pct="''${1:-}"
    case "$pct" in
      ""|*[!0-9]*) echo "usage: affinity-scale <percent>   e.g. 135, 150, 170, 200" >&2; exit 1 ;;
    esac
    dpi=$(( (96 * pct + 50) / 100 ))   # round to nearest

    wine reg add "HKCU\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d "$dpi" /f
    echo ">> Wine DPI set to $dpi ($pct%). Restart Affinity to apply."
  '';

  affinity = pkgs.writeShellScriptBin "affinity" ''
    set -euo pipefail
    export PATH="${pkgs.lib.makeBinPath [ wine ]}:$PATH"
    export WINEPREFIX="''${WINEPREFIX:-$HOME/.affinity}"

    base="$WINEPREFIX/drive_c/Program Files/Affinity"
    app="''${1:-}"

    if [ -z "$app" ]; then
      # Default: the unified "Affinity by Canva" app.
      dir="$base/Affinity"
    else
      dir="$(find "$base" -maxdepth 1 -type d -iname "*$app*" 2>/dev/null | head -n1 || true)"
    fi

    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
      echo "Affinity ''${app:-(by Canva)} not found under $base — run 'affinity-setup' and install it first." >&2
      exit 1
    fi

    # Prefer a canonically named launcher, else the first real .exe.
    exe=""
    for cand in "$dir/Affinity.exe" "$dir/$app.exe"; do
      [ -f "$cand" ] && exe="$cand" && break
    done
    [ -z "$exe" ] && exe="$(find "$dir" -maxdepth 1 -iname '*.exe' \
      ! -iname '*unins*' ! -iname '*.real.exe' ! -iname '*crash*' | head -n1)"

    exec wine "$exe" "''${@:2}"
  '';
in
{
  environment.systemPackages = [ pkgs.winetricks affinity-setup affinity-winefix affinity-scale affinity ];
}
