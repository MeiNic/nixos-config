# shellcheck shell=bash
# SNAP and USB_DEVICE are set by default.nix.

bold()  { printf "\e[1m%s\e[0m\n" "$*"; }
green() { printf "\e[32m%s\e[0m\n" "$*"; }
red()   { printf "\e[31m%s\e[0m\n" "$*"; }
dim()   { printf "\e[2m%s\e[0m\n"  "$*"; }
stamp() { date -d "@$(stat -c %Y "$1")" '+%F %H:%M'; }

echo ""
bold "══════════════════════════════════════════"
bold "  Backup Status Overview"
bold "══════════════════════════════════════════"

echo ""
bold "● Systemd Timers"
systemctl list-timers offsite-backup.timer usb-backup.timer btrbk.timer \
  --no-pager 2>/dev/null | grep -v "^$" || true

echo ""
bold "● BTRFS Snapshots ($SNAP)"
if mountpoint -q "$SNAP" 2>/dev/null; then
  green "  Mounted ✓"
  # No sizes: du takes minutes here and counts shared data once per snapshot.
  for n in $(ls -1 "$SNAP" | sed 's/\..*//' | sort -u); do
    LIST=$(ls -1 "$SNAP" | grep "^$n\." \
      | sed -E 's/^[^.]*\.(....)(..)(..)T(..)(..)$/\1-\2-\3 \4:\5/')
    printf "  %-8s %3s snapshots   oldest %s   newest %s\n" \
      "$n" "$(wc -l <<<"$LIST")" "$(head -1 <<<"$LIST")" "$(tail -1 <<<"$LIST")"
  done
else
  red "  $SNAP not mounted"
fi

# borg_job <unit> <heading> <what a pause waits for>
borg_job() {
  local unit=$1 st=/var/lib/$1 since cur
  echo ""
  bold "● $2"
  if [ -e "$st/last-success" ]; then echo "  Last success: $(stamp "$st/last-success")"
  else red "  No successful backup yet"; fi
  if [ "$(systemctl show "$unit" -p ActiveState --value)" = activating ]; then
    since=$(systemctl show "$unit" -p ExecMainStartTimestamp --value)
    green "  Running now: $(cat "$st/pending" 2>/dev/null || echo "repository check") (since $since)"
    # Progress line logged every 10 min by borg-job.sh; its byte counters are often 0.
    cur=$(journalctl -u "$unit" --since "$since" -o cat 2>/dev/null \
      | grep -E ' [0-9.]+ [kMGTP]?B/[0-9.]+ [kMGTP]?B$' | tail -1 \
      | sed -E 's/ [0-9.]+ [kMGTP]?B\/[0-9.]+ [kMGTP]?B$//')
    [ -n "$cur" ] && echo "  Working on (updated every 10 min): $cur"
  elif [ -e "$st/pending" ]; then
    echo "  Unfinished run: $(cat "$st/pending") (resumes when $3 are back)"
  fi
  [ -e "$st/last-failure" ] && red "  Last failure: $(stamp "$st/last-failure")  (retries after 1 h)"
  if [ -e "$st/last-check" ]; then echo "  Last repo check: $(stamp "$st/last-check")  (every 30 days)"
  else echo "  Last repo check: never (runs after the next backup)"; fi
}
borg_job offsite-backup "Offsite backup  [Hetzner Storage Box - needs AC power + ethernet]" "power + ethernet"
borg_job usb-backup "USB backup  [USB hard drive - needs AC power + the drive]" "power + the drive"

echo ""
bold "● Conditions right now"
if systemd-analyze condition 'ConditionACPower=true' >/dev/null 2>&1
then green "  AC power: connected ✓"; else red "  AC power: not connected"; fi
if nmcli -t -f TYPE,STATE device 2>/dev/null | grep -qx 'ethernet:connected'
then green "  Ethernet: connected ✓"; else red "  Ethernet: not connected"; fi
if [ -b "$USB_DEVICE" ]
then green "  USB drive: connected ✓"; else red "  USB drive: not connected"; fi

echo ""
bold "══════════════════════════════════════════"
echo "  Start (if due):   sudo systemctl start offsite-backup | usb-backup"
echo "  Live log:         journalctl -fu offsite-backup | usb-backup | btrbk"
bold "══════════════════════════════════════════"
echo ""
