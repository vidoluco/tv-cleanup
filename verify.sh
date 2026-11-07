#!/bin/bash
# Check the TV after the changes: home screen, reboot, then everything again.
. "$(dirname "$0")/env.sh"
DIR="$HERE"
s() { adb -s "$T" shell "$@" </dev/null; }

check() {
  echo "boot_completed=$(s getprop sys.boot_completed | tr -d '\r')"
  s input keyevent KEYCODE_HOME
  perl -e 'select(undef,undef,undef,6)'
  echo "focus: $(s dumpsys activity activities | grep -m1 -E 'mResumedActivity|topResumedActivity' | sed -E 's/^ *//' | cut -c1-110)"
  adb -s "$T" exec-out screencap -p > "$DIR/$1.png" </dev/null
  echo "screenshot $1.png: $(wc -c < "$DIR/$1.png" | tr -d ' ') bytes"
  for p in com.google.android.youtube.tv com.netflix.ninja com.spotify.tv.android com.amazon.amazonvideo.livingroom com.realtek.airplay2 com.tcl.tvinput com.tcl.ui_mediaCenter com.google.android.katniss com.google.android.apps.mediashell; do
    echo "  $p enabled=$(s pm list packages -e | tr -d '\r' | grep -cx "package:$p")"
  done
  echo "crash lines: $(s logcat -b crash -d | grep -c 'FATAL EXCEPTION')"
  echo "disabled: $(s pm list packages -d | wc -l | tr -d ' ')"
  echo "anim: $(s settings get global window_animation_scale) $(s settings get global transition_animation_scale) $(s settings get global animator_duration_scale)"
  s cat /proc/meminfo | sed -n '3p'
}

echo '=== before reboot ==='
check after-home

echo '=== rebooting ==='
adb -s "$T" reboot </dev/null
perl -e 'select(undef,undef,undef,25)'

ok=0
for i in $(seq 1 36); do
  adb connect "$T" >/dev/null 2>&1 </dev/null
  if [ "$(s getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then ok=1; echo "back after about $((25 + i*5))s"; break; fi
  perl -e 'select(undef,undef,undef,5)'
done
if [ $ok -ne 1 ]; then echo 'TV NOT reachable after reboot within 3 minutes'; adb devices -l; exit 2; fi

# let boot receivers settle before judging
perl -e 'select(undef,undef,undef,45)'
echo '=== after reboot ==='
check after-reboot
