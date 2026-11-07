#!/bin/bash
# Run an automatic Racing Karts race in the TV's TCL browser and measure frames.
# Usage: kart-perf.sh <label> "<query>" [seconds before measuring]
# Needs the game server running on this Mac. Screenshots go to the current folder.
. "$(dirname "$0")/env.sh"
HOST="${KART_HOST:?set KART_HOST=<this computer ip>:5191 in local.env}"
LABEL="$1"; QUERY="$2"; WARM="${3:-40}"
COMP=com.tcl.browser/.portal.browse.activity.BrowsePageActivity
s() { adb -s "$T" shell "$@" </dev/null | tr -d '\r'; }

s am force-stop com.tcl.browser
sleep 1
s logcat -c
s am start -n "$COMP" -a android.intent.action.VIEW -d "'http://$HOST/?$QUERY'" >/dev/null # quoted twice: the TV's shell would cut the URL at the first &
sleep "$WARM"
s dumpsys gfxinfo com.tcl.browser reset >/dev/null
sleep 15
s dumpsys gfxinfo com.tcl.browser | grep -E 'Total frames rendered|50th percentile|90th percentile' | head -3 |
  awk -v l="$LABEL" 'NR==1{f=$4; printf "%s: %d frames in 15s = %.1f fps | ", l, f, f/15} NR>1{printf "%s ", $0} END{print ""}'
adb -s "$T" exec-out screencap -p > "kart-$LABEL.png" </dev/null
echo "  mem: $(s cat /proc/meminfo | sed -n 3p | awk '{print int($2/1024)" MB"}')  focus: $(s dumpsys window | grep -m1 mCurrentFocus | sed -E 's/.* u0 //' | cut -c1-40)"
echo "  died: $(s logcat -d | grep 'has died' | sed -E 's/.*Process ([^ ]+).*/\1/' | sort -u | tr '\n' ' ')"
