#!/bin/bash
# Read-only inspection. Changes nothing on the TV.
. "$(dirname "$0")/env.sh"
s() { adb -s "$T" shell "$@"; }

echo '=== memory by process (top 30) ==='
s dumpsys meminfo | sed -n '/Total PSS by process/,/Total PSS by OOM/p' | head -32

echo '=== last used (usagestats) ==='
s dumpsys usagestats 2>/dev/null | grep -E 'package=.*totalTimeUsed=.*lastTimeUsed' | sed -E 's/^ *//' | sed -E 's/(package=[^ ]+).*totalTimeUsed="?([^" ]+)"? *lastTimeUsed="?([^"]+ [^"]+|[^" ]+)"?.*/\1 used=\2 last=\3/' | sort -u | head -60

echo '=== candidate details ==='
for p in tv.samba.ssm.ui com.tcl.exhibit com.tcl.esticker com.tcl.waterfall.overseas com.tcl.channelplus com.tcl.logkit \
         com.tcl.ocean.instructions com.tcl.repairguide com.tcl.messagebox com.tcl.smartalexa com.tcl.usercenter \
         com.tcl.interactive com.tcl.t_solo com.tcl.ttvs com.tcl.dashboard com.tcl.suspension com.tcl.guard \
         com.tcl.useragreement com.tcl.tv.tclhome_passive com.tcl.partnercustomizer \
         com.google.android.feedback com.google.android.play.games com.google.android.marvin.talkback \
         com.google.android.youtube.tvmusic com.iqiyi.i18n.tv com.amazon.amazonvideo.livingroom com.wbd.stream \
         com.netflix.ninja com.netflix.tokenmanager com.airconsole.androidtv; do
  d=$(s dumpsys package "$p" 2>/dev/null)
  flags=$(echo "$d" | grep -m1 -E '^ *pkgFlags=' | sed -E 's/ *pkgFlags=//')
  persistent=$(echo "$flags" | grep -c PERSISTENT)
  sysuid=$(echo "$d" | grep -m1 -E 'sharedUser=' | sed -E 's/ *sharedUser=//')
  home=$(echo "$d" | grep -c 'android.intent.category.HOME')
  boot=$(echo "$d" | grep -c 'BOOT_COMPLETED')
  pid=$(s pidof "$p" 2>/dev/null)
  echo "$p | persistent=$persistent home=$home boot=$boot running=${pid:-no} sharedUser=${sysuid:-none}"
done

echo '=== device owner / admins ==='
s dumpsys device_policy 2>/dev/null | grep -E 'admin=|Device Owner|Profile Owner' | head

echo '=== who is home / launcher ==='
s cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN

echo '=== current animation scales ==='
for k in window_animation_scale transition_animation_scale animator_duration_scale; do echo "$k=$(s settings get global $k)"; done

echo '=== ACR / ad related settings ==='
s settings list global | grep -iE 'acr|samba|advert|ad_id|limit_ad|tracking|usage_stat|send_action|analytics'
s settings list secure | grep -iE 'acr|samba|advert|ad_id|limit_ad|tracking|analytics'
