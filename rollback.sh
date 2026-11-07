#!/bin/bash
# Undo everything apply.sh did: re-enable the listed apps and restore animation speed.
. "$(dirname "$0")/env.sh"
DIR="$HERE"
adb connect "$T" >/dev/null 2>&1
s() { adb -s "$T" shell "$@"; }

grep -v '^#' "$DIR/disable-list.txt" | cut -d'|' -f1 | tr -d ' ' | while read -r p; do
  [ -n "$p" ] || continue
  echo "enable $p: $(s pm enable --user 0 "$p" 2>&1 </dev/null)"
done
s settings put global window_animation_scale 1.0 </dev/null
s settings put global transition_animation_scale 1.0 </dev/null
s settings delete global animator_duration_scale </dev/null
echo "rollback finished"
