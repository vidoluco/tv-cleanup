#!/bin/bash
# Keep Brave on the TV up to date. Brave was installed from its APK, so the Play Store never updates it.
# At most once every 30 days: if brave/brave-browser has a newer stable release, download BraveMonoarm.apk
# (32-bit ARM), check its SHA-256 against the digest GitHub publishes, and install it over the old one.
# Android only accepts the update if it is signed with the same key as the Brave already installed.
#
# Usage: update-brave.sh            run by launchd every night; does nothing until 30 days have passed
#        update-brave.sh --force    check now
#        update-brave.sh --reinstall-test   check now and reinstall even the same version (tests every step)
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
. "$(dirname "$0")/env.sh"
DIR="$HERE"
STATE="$DIR/.brave-update-last"   # epoch seconds of the last completed check
LOG="$DIR/update-brave.log"
ASSET=BraveMonoarm.apk
PKG=com.brave.browser

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }
note() { osascript -e "display notification \"$1\" with title \"Brave sulla TV\"" >/dev/null 2>&1 || true; }
done_check() { date +%s > "$STATE"; }
s() { adb -s "$T" shell "$@" </dev/null | tr -d '\r'; }

MODE="${1:-}"
if [ -z "$MODE" ] && [ -f "$STATE" ]; then
  age=$(( $(date +%s) - $(cat "$STATE") ))
  [ "$age" -lt $((30 * 86400)) ] && exit 0
fi

# An adb server started here, under launchd, may lack macOS's Local Network permission. Stop it when done, so
# it does not linger and cut off adb for everything else.
pgrep -qf 'adb.*fork-server' || trap 'adb kill-server >/dev/null 2>&1' EXIT

adb connect "$T" >/dev/null 2>&1 </dev/null
if [ "$(adb -s "$T" get-state 2>/dev/null </dev/null)" != device ]; then
  log "TV not reachable at $T; will try again tomorrow"; exit 0
fi
if s dumpsys window | grep -m1 mCurrentFocus | grep -q "$PKG"; then
  log "Brave is on screen; will try again tomorrow"; exit 0
fi

have=$(s dumpsys package "$PKG" | grep -m1 -oE 'versionName=[0-9.]+' | cut -d= -f2)
json=$(curl -fsSL --max-time 30 https://api.github.com/repos/brave/brave-browser/releases/latest) \
  || { log "GitHub not reachable; will try again tomorrow"; exit 0; }
read -r tag url digest <<< "$(python3 -I -c '
import json, sys
r = json.load(sys.stdin)
a = [a for a in r.get("assets", []) if a["name"] == sys.argv[1]]
ok = not r.get("prerelease") and not r.get("draft") and a and (a[0].get("digest") or "").startswith("sha256:")
print(r["tag_name"], a[0]["browser_download_url"], a[0]["digest"][7:]) if ok else print("- - -")
' "$ASSET" <<< "$json")"
if [ "$tag" = "-" ]; then log "latest release has no checked $ASSET; will try again tomorrow"; exit 0; fi
latest=${tag#v}

newer=$(printf '%s\n%s\n' "$have" "$latest" | sort -V | tail -1)
if [ "$MODE" != "--reinstall-test" ] && { [ "$have" = "$latest" ] || [ "$newer" = "$have" ]; }; then
  log "up to date: TV has $have, latest stable is $latest"; done_check; exit 0
fi

tmp=$(mktemp -d)
trap "rm -rf '$tmp'; $(trap -p EXIT | sed -E "s/^trap -- '(.*)' EXIT$/\1/")" EXIT
log "downloading $tag ($have on the TV)"
curl -fsSL --max-time 1800 -o "$tmp/$ASSET" "$url" || { log "download failed; will try again tomorrow"; exit 0; }
got=$(shasum -a 256 "$tmp/$ASSET" | cut -d' ' -f1)
if [ "$got" != "$digest" ]; then
  log "CHECKSUM MISMATCH for $tag: got $got, GitHub says $digest. Not installed."
  note "Aggiornamento NON installato: checksum sbagliato"; exit 1
fi

out=$(adb -s "$T" install -r "$tmp/$ASSET" </dev/null 2>&1 | tail -1)
now=$(s dumpsys package "$PKG" | grep -m1 -oE 'versionName=[0-9.]+' | cut -d= -f2)
if [ "$out" = "Success" ] && [ "$now" = "$latest" ]; then
  log "installed Brave $now (was $have)"; done_check
  note "Brave aggiornato a $now"
else
  log "install failed: $out (TV has $now)"
  note "Aggiornamento di Brave fallito: vedi update-brave.log"; exit 1
fi
