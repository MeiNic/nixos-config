# =============================================================================
# Desktop Environment, Display & Input
# =============================================================================
{ config, pkgs, ... }:

{
  # ── X11 / Display Manager ──────────────────────────────────────────────────
  services.xserver.enable = true;

  # Cinnamon Desktop Environment
  services.xserver.displayManager.lightdm.enable  = true;
  services.xserver.desktopManager.cinnamon.enable = true;

  # --- KDE Plasma (commented out for quick switch) --------------------------
  # services.displayManager.sddm.enable      = true;
  # services.desktopManager.plasma6.enable   = true;
  # systemd.user.services.birdtray           = { ... };
  # systemd.user.services.plasmaCustomization = { ... };

  # ── Keyboard Layout ────────────────────────────────────────────────────────
  services.xserver.xkb = {
    layout  = "de";
    variant = "";
  };

  console.keyMap = "de";

  # ── Touchpad ───────────────────────────────────────────────────────────────
  services.libinput.enable = true;

  # ── Audio (PipeWire) ───────────────────────────────────────────────────────
  security.rtkit.enable = true;

  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
    wireplumber.enable = true;
    # jack.enable = true;
  };

  # ── Printing ───────────────────────────────────────────────────────────────
  services.printing.enable = true;

  # ── Fingerprint Sensor ────────────────────────────────────────────────────
  services.fprintd.enable = true;

  # ── System Packages (desktop-related) ─────────────────────────────────────
  environment.systemPackages = with pkgs; [
    budgie-desktop
    gnome-keyring
    gnome-terminal
    dconf             # needed for the panel-setup script below
  ];

  # ── Cinnamon Multi-Monitor Taskbar ─────────────────────────────────────────
  #
  # Cinnamon only creates a panel on the primary monitor by default.
  # The service below runs on login AND on every display hotplug event,
  # dynamically adding a bottom panel to every connected monitor.
  #
  # Cinnamon panel-zone format:  "<panel-id>:<monitor-index>:<position>:<size>"
  #   position: 0=top  1=bottom  2=left  3=right
  #   size: pixel height (0 = auto)
  #
  # Panel layout on each monitor:
  #   Left:   App-menu + Window-list
  #   Center: (empty)
  #   Right:  Systray + Calendar
  #
  # The number of panels is detected at runtime from xrandr, so it works
  # automatically whether you have 1, 2, or more monitors connected.
  # ───────────────────────────────────────────────────────────────────────────

  # The script is stored in the Nix store so both the service and the
  # udev-triggered root wrapper can reference the same path.
  environment.etc."cinnamon-panel-setup.sh" = {
    mode = "0555";
    text = ''
      #!/bin/sh
      # Apply Cinnamon bottom-panel dconf settings for every connected monitor.
      # Runs as the target user (nico) inside their D-Bus session.
      set -eu

      DCONF="${pkgs.dconf}/bin/dconf"
      XRANDR="${pkgs.xorg.xrandr}/bin/xrandr"
      USERNAME="nico"
      USER_ID=$(id -u "$USERNAME" 2>/dev/null || true)
      DISPLAY_ENV="$\{DISPLAY:-:0}"

      if [ -z "$USER_ID" ]; then
        echo "cinnamon-panel-setup: user $USERNAME not found, skipping." >&2
        exit 0
      fi

      # Count connected monitors via xrandr (works on X11/lightdm sessions).
      MONITOR_COUNT=$(
        DISPLAY="$DISPLAY_ENV" \
        XAUTHORITY="/home/$USERNAME/.Xauthority" \
          "$XRANDR" --query 2>/dev/null \
          | grep -c " connected" || true
      )

      # Fall back to 1 if xrandr isn't usable yet (e.g. called too early).
      if [ -z "$MONITOR_COUNT" ] || [ "$MONITOR_COUNT" -lt 1 ]; then
        MONITOR_COUNT=1
      fi

      # Build dconf list values dynamically.
      PANELS_ENABLED=""
      PANELS_AUTOHIDE=""
      PANELS_HIDE_DELAY=""
      PANELS_SHOW_DELAY=""

      i=0
      while [ "$i" -lt "$MONITOR_COUNT" ]; do
        PANEL_ID=$((i + 1))
        PANELS_ENABLED="$PANELS_ENABLED'$PANEL_ID:$i:1:0', "
        PANELS_AUTOHIDE="$PANELS_AUTOHIDE'$PANEL_ID:false', "
        PANELS_HIDE_DELAY="$PANELS_HIDE_DELAY'$PANEL_ID:0', "
        PANELS_SHOW_DELAY="$PANELS_SHOW_DELAY'$PANEL_ID:0', "
        i=$((i + 1))
      done

      # Strip trailing ", "
      PANELS_ENABLED="[''${PANELS_ENABLED%, }]"
      PANELS_AUTOHIDE="[''${PANELS_AUTOHIDE%, }]"
      PANELS_HIDE_DELAY="[''${PANELS_HIDE_DELAY%, }]"
      PANELS_SHOW_DELAY="[''${PANELS_SHOW_DELAY%, }]"

      run_dconf() {
        local key="$1" val="$2"
        DISPLAY="$DISPLAY_ENV" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" \
        HOME="/home/$USERNAME" \
        XDG_RUNTIME_DIR="/run/user/$USER_ID" \
          su -s /bin/sh "$USERNAME" -c \
            "$DCONF write \"$key\" \"$val\"" || true
      }

      run_dconf /org/cinnamon/panels-enabled    "$PANELS_ENABLED"
      run_dconf /org/cinnamon/panels-autohide   "$PANELS_AUTOHIDE"
      run_dconf /org/cinnamon/panels-hide-delay "$PANELS_HIDE_DELAY"
      run_dconf /org/cinnamon/panels-show-delay "$PANELS_SHOW_DELAY"

      # Apply identical applet layout to every panel.
      i=0
      while [ "$i" -lt "$MONITOR_COUNT" ]; do
        PANEL_ID=$((i + 1))
        # Applet IDs must be globally unique across all panels.
        ID_MENU=$((PANEL_ID * 10 + 0))
        ID_WINLIST=$((PANEL_ID * 10 + 1))
        ID_SYSTRAY=$((PANEL_ID * 10 + 2))
        ID_CALENDAR=$((PANEL_ID * 10 + 3))

        run_dconf "/org/cinnamon/panel-zone-left-applets" \
          "'{\"$PANEL_ID\":[{\"uuid\":\"menu@cinnamon.org\",\"id\":$ID_MENU},{\"uuid\":\"grouped-window-list@cinnamon.org\",\"id\":$ID_WINLIST}]}'"
        run_dconf "/org/cinnamon/panel-zone-center-applets" \
          "'{\"$PANEL_ID\":[]}'"
        run_dconf "/org/cinnamon/panel-zone-right-applets" \
          "'{\"$PANEL_ID\":[{\"uuid\":\"systray@cinnamon.org\",\"id\":$ID_SYSTRAY},{\"uuid\":\"calendar@cinnamon.org\",\"id\":$ID_CALENDAR}]}'"

        i=$((i + 1))
      done

      # ── Keyboard shortcuts ─────────────────────────────────────────────────
      # Lock screen: Ctrl+L  (default is Ctrl+Alt+L)
      run_dconf /org/cinnamon/desktop/keybindings/system/screensaver "['<Primary>l']"

      echo "cinnamon-panel-setup: configured $MONITOR_COUNT panel(s)."
    '';
  };

  # User systemd service – runs at login and can be re-triggered on hotplug.
  # After a display change Cinnamon must be restarted to pick up the new
  # dconf values; the ExecStartPost line does that non-fatally.
  systemd.user.services.cinnamon-panel-setup = {
    description = "Apply Cinnamon bottom-panel layout for all connected monitors";
    # Start after the graphical session is up so dconf/xrandr work.
    after    = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = false;
      ExecStart       = "/etc/cinnamon-panel-setup.sh";
      # Soft-restart Cinnamon so it re-reads the new panel config.
      # '|| true' keeps the unit green even if cinnamon isn't running yet.
      ExecStartPost   = "${pkgs.bash}/bin/bash -c '${pkgs.procps}/bin/pkill -HUP -x cinnamon || true'";
    };
  };

  # udev rule – fires when any DRM connector changes state (plug / unplug).
  # It starts the user service in the context of the logged-in user (uid 1000).
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", RUN+="${pkgs.systemd}/bin/systemctl --machine=nico@.host --user start cinnamon-panel-setup.service"
  '';
}
