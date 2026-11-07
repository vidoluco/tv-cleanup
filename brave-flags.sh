#!/bin/bash
# Start Brave with Chromium switches on the TV, or remove them.
# Usage: brave-flags.sh "<switches>" [url]   set switches and start Brave
#        brave-flags.sh --clear              remove switches
# Brave only reads the file while it is the Android "debug app".
. "$(dirname "$0")/env.sh"
PKG=com.brave.browser
FILE=/data/local/tmp/chrome-command-line
s() { adb -s "$T" shell "$@" </dev/null | tr -d '\r'; }

if [ "$1" = "--clear" ]; then
  s rm -f "$FILE"
  s am clear-debug-app
  s am force-stop "$PKG"
  echo "cleared; debug_app=$(s settings get global debug_app)"
  exit 0
fi

s "echo '_ $1' > $FILE"
s am set-debug-app --persistent "$PKG"
s am force-stop "$PKG"
sleep 2
s am start -n "$PKG/com.google.android.apps.chrome.Main" -a android.intent.action.VIEW -d "'${2:-https://github.com/vidoluco}'" | tail -1
echo "debug_app=$(s settings get global debug_app) file=$(s cat "$FILE")"
