#!/bin/bash
# Read-only snapshot of the TV state. Changes nothing on the TV.
set -u
. "$(dirname "$0")/env.sh"
D="$HERE/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$D"
s() { adb -s "$T" shell "$@"; }

s getprop > "$D/getprop.txt"
s pm list packages -f > "$D/packages-all.txt"
s pm list packages -d > "$D/packages-disabled-before.txt"
s pm list packages -e > "$D/packages-enabled-before.txt"
s pm list packages -s > "$D/packages-system.txt"
s pm list packages -3 > "$D/packages-third-party.txt"
s settings list global > "$D/settings-global.txt"
s settings list secure > "$D/settings-secure.txt"
s settings list system > "$D/settings-system.txt"
s cat /proc/meminfo > "$D/meminfo.txt"
s df -h > "$D/df.txt" 2>&1
adb -s "$T" exec-out screencap -p > "$D/screen-before.png"

for f in packages-all packages-enabled-before; do
  [ -s "$D/$f.txt" ] || { echo "ERROR: $f is empty, backup not valid" >&2; exit 1; }
done
echo "$D" > "$HERE/LATEST_BACKUP"
echo "$D"
