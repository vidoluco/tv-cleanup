#!/bin/bash
# Disable the listed apps one at a time. After each one, check the TV is healthy;
# if not, re-enable that app and stop. If the TV goes away, stop without guessing.
. "$(dirname "$0")/env.sh"
DIR="$HERE"
LOG="$DIR/apply.log"
s() { adb -s "$T" shell "$@" </dev/null; }
log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG"; }

# 0 healthy, 1 unhealthy, 2 TV unreachable
health() {
  [ "$(adb -s "$T" get-state 2>/dev/null </dev/null)" = "device" ] || return 2
  [ "$(s getprop sys.boot_completed | tr -d '\r')" = "1" ] || return 1
  s pidof com.android.systemui | grep -q '[0-9]' || return 1
  s cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN \
    | grep -q 'com.google.android.apps.tv.launcherx' || return 1
  crashes=$(s logcat -b crash -d | grep -c 'FATAL EXCEPTION\|Process: ')
  [ "$crashes" -le "$BASE_CRASH" ] || { log "new crash lines: $crashes (baseline $BASE_CRASH)"; return 1; }
  return 0
}

BASE_CRASH=$(s logcat -b crash -d | grep -c 'FATAL EXCEPTION\|Process: ')
log "start, crash baseline $BASE_CRASH"
health; rc=$?
[ $rc -eq 0 ] || { log "TV not healthy before starting (rc=$rc), nothing changed"; exit 1; }

while IFS='|' read -r p why; do
  p=$(echo "$p" | tr -d ' ')
  case "$p" in ''|\#*) continue;; esac
  out=$(s pm disable-user --user 0 "$p" 2>&1 | tr -d '\r')
  state=$(s pm list packages -d | tr -d '\r' | grep -cx "package:$p")
  if [ "$state" != "1" ]; then log "NOT disabled $p: $out"; continue; fi
  log "disabled $p"
  # give boot receivers and dependants time to complain
  perl -e 'select(undef,undef,undef,4)'
  health; rc=$?
  if [ $rc -eq 2 ]; then log "TV unreachable after $p, stopping"; exit 2; fi
  if [ $rc -ne 0 ]; then
    log "UNHEALTHY after $p, re-enabling and stopping"
    s pm enable --user 0 "$p" >/dev/null 2>&1
    exit 1
  fi
done < "$DIR/disable-list.txt"

s settings put global window_animation_scale 0.5
s settings put global transition_animation_scale 0.5
s settings put global animator_duration_scale 0.5
log "animations 0.5"
health; rc=$?
log "final health rc=$rc"
exit $rc
