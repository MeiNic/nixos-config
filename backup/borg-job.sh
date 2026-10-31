# shellcheck shell=bash
# Borg job script for offsite-backup and usb-backup. borg.nix puts the job's
# settings (job state host title target lost repo user excludes paths,
# BORG_PASSCOMMAND) and hooks (condition, optional prepare/release) in front.
#
# Runs only if the last success is >24 h old (or a run is unfinished), the last
# failure is >1 h old, and AC power + condition() hold. If they stop holding
# mid-run, borg is stopped and the next start resumes the same archive.

set -u
export BORG_BASE_DIR="$state/borg"
failure_note="See: journalctl -u $job"
done_note=""

log()  { echo "$job: $*"; }
age()  { echo $(( $(date +%s) - $(stat -c %Y "$1") )); }
gate() { systemd-analyze condition 'ConditionACPower=true' >/dev/null 2>&1 && condition; }

declare -F prepare >/dev/null || prepare() { :; }
declare -F release >/dev/null || release() { :; }

notify() {
  local uid
  uid=$(id -u "$user") || return 0
  [ -S "/run/user/$uid/bus" ] || return 0
  runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
    notify-send -a "$title" -u "$1" -i drive-harddisk "$2" "$3" || true
}

# 143 = stopped by systemd (e.g. shutdown), not a failure.
on_exit() {
  local rc=$?
  trap - EXIT
  release
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 143 ]; then
    touch "$state/last-failure"
    notify critical "$title failed" "$failure_note"
  fi
  exit "$rc"
}
trap on_exit EXIT
trap 'exit 143' TERM
fail() { failure_note="$1"; log "$1" >&2; exit 1; }
stop_paused() {
  notify low "$title paused" "Lost $lost - it continues where it stopped once both are back."
  exit 0
}

install -d -m 755 "$state"
install -d -m 700 "$state/borg"
if [ ! -e "$state/pending" ] && [ -e "$state/last-success" ] \
   && [ "$(age "$state/last-success")" -lt 86400 ]; then exit 0; fi
if [ -e "$state/last-failure" ] && [ "$(age "$state/last-failure")" -lt 3600 ]; then exit 0; fi
gate || exit 0
prepare

# Runs a borg command and stops it (SIGTERM) when the conditions stop holding.
paused=0
guarded() {
  "$@" &
  local pid=$! ticks=0 rc
  while kill -0 "$pid" 2>/dev/null; do
    if ! gate; then
      log "$lost lost - stopping borg, will resume when both are back"
      paused=1
      kill -TERM "$pid" 2>/dev/null
      break
    fi
    sleep 5
    # Every 10 min borg logs its current file (shown by backup-status).
    ticks=$((ticks + 1))
    [ $((ticks % 120)) -eq 0 ] && kill -USR1 "$pid" 2>/dev/null
  done
  wait "$pid"
  rc=$?
  # A pulled drive makes borg fail before the next poll - still a pause.
  if [ "$rc" -gt 1 ] && [ "$paused" -eq 0 ] && ! gate; then
    log "$lost lost - borg stopped, will resume when both are back"
    paused=1
  fi
  return "$rc"
}

if ! out=$(borg info "$repo" 2>&1); then
  if grep -q 'does not exist' <<<"$out"; then
    log "repository does not exist yet - initialising (repokey-blake2)"
    borg init --encryption=repokey-blake2 "$repo" || fail "borg init failed"
  else
    echo "$out" >&2
    fail "cannot open repository: $(tail -n 1 <<<"$out")"
  fi
fi

# The archive name survives pauses, so a resumed create reuses the stored chunks.
if [ ! -e "$state/pending" ]; then
  echo "$host-$(date +%Y-%m-%dT%H%M)" > "$state/pending"
  rm -f "$state/created"
fi
name=$(cat "$state/pending")

if [ ! -e "$state/created" ]; then
  log "creating archive $name"
  guarded borg create \
    --info --stats --show-rc \
    --compression auto,zstd,3 \
    --checkpoint-interval 180 \
    --one-file-system \
    --exclude-caches \
    --exclude-if-present .nobackup \
    --exclude-from "$excludes" \
    "$repo::$name" \
    "${paths[@]}"
  rc=$?
  [ "$paused" -eq 1 ] && stop_paused
  [ "$rc" -le 1 ] || fail "borg create failed (exit code $rc)"   # 1 = warnings only
  touch "$state/created"
fi

log "pruning old archives"
guarded borg prune \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
  --glob-archives "$host-*" \
  "$repo"
rc=$?
[ "$paused" -eq 1 ] && stop_paused
[ "$rc" -le 1 ] || fail "borg prune failed (exit code $rc)"

guarded borg compact "$repo"
rc=$?
[ "$paused" -eq 1 ] && stop_paused
[ "$rc" -le 1 ] || fail "borg compact failed (exit code $rc)"

rm -f "$state/pending" "$state/created" "$state/last-failure"
touch "$state/last-success"
log "done: $name"
done_note="$name is safe on $target."

# Monthly check, before the success notification so "finished" means the drive
# is free. Unlike create, check exits 1 when it finds problems.
if [ ! -e "$state/last-check" ] || [ "$(age "$state/last-check")" -ge 2592000 ]; then
  log "monthly repository check"
  guarded borg check --repository-only --show-rc "$repo"
  rc=$?
  if [ "$paused" -eq 1 ]; then
    done_note="$done_note Repository check postponed to the next run."
  else
    [ "$rc" -eq 0 ] || fail "Repository check found problems (exit code $rc). Read the log before running any repair."
    touch "$state/last-check"
    log "repository check passed"
  fi
fi

release
notify normal "$title finished" "$done_note"
