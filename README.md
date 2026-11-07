# tv-cleanup

Reversible cleanup for a TCL Google TV over adb, without root, plus what it took to make Brave usable with a TV remote. Tested on one set: TCL G10 (55V6C), Android 12, 1.8 GB RAM, 32-bit (`armeabi-v7a`), PowerVR GPU.

Apps are disabled with `pm disable-user`, never uninstalled.

> Not affiliated with Brave Software or TCL. "Brave" and the Brave lion are Brave Software's trademarks. This repo does not contain the logo: the tile's build fetches it from `brave/brave-core` for a local build.

## Setup

Turn on network debugging on the TV, then:

```bash
cp local.env.example local.env   # put the TV's address in it
. ./local.env && adb connect "$TV"
```

Every script reads `local.env` (kept out of git) through `env.sh`.

On macOS, `No route to host` for every local device except the router can mean the app running adb lacks the Local Network permission.

## Scripts

| File | What it does | Changes the TV |
|---|---|---|
| `backup.sh` | Saves properties, app lists, settings and a screenshot to `backup-<date>/` | No |
| `inspect.sh` | Shows memory, last use and details of candidate apps | No |
| `disable-list.txt` | The apps to disable, with the reason for each | - |
| `apply.sh` | Disables one app at a time and checks the TV after each; re-enables and stops if unhealthy | Yes |
| `rollback.sh` | Re-enables the listed apps and restores animation speed | Yes |
| `verify.sh` | Checks home, reboots the TV, checks again | Reboots |
| `brave-flags.sh` | Sets or clears Chromium switches for Brave | Yes |
| `update-brave.sh` | Installs a newer stable Brave, at most once a month | Yes |
| `brave-tile/` | A TV app-list entry, start page and remote pointer for Brave | Yes, once installed |
| `kart-perf.sh` | Runs a Racing Karts test race in the TCL browser and measures frames | Opens a browser |

## Cleanup

```bash
bash backup.sh
bash apply.sh
bash verify.sh
```

To undo:

```bash
bash rollback.sh
```

Known effects:

- `com.tcl.channelplus`: free channels may also disappear from Live TV.
- `com.tcl.smartalexa`, `com.tcl.usercenter`: Alexa and the TCL account stop working.
- `com.tcl.waterfall.overseas`: one report of a bootloop on an older TV. It survived one reboot here.
- A firmware update can bring disabled apps back.
- Network debugging leaves port 5555 open on the local network. A new computer must still be approved on the TV: never accept a debugging prompt you did not cause. Brave's switches below probably need debugging to stay on.

Not covered:

- The Google TV home, including its promoted rows, is not touched.
- `rollback.sh` does not remove apps installed afterwards (Brave, SmartTube, the tile) or Brave's switches (`brave-flags.sh --clear`).

## Brave on this TV

Brave has no official TV build. The phone APK `BraveMonoarm.apk` installs and runs, with these limits and fixes:

- **Corrupted pages.** With the default ANGLE OpenGL ES backend on this PowerVR GPU, page text turns into garbage tiles. Switching ANGLE to Vulkan fixes it.
- **Remote.** Without spatial navigation the arrows only scroll. With it, the arrows move between links and buttons and OK presses them. The Menu key opens Brave's menu. The top bar cannot be reached with the arrows: see the pointer below.
- **Video.** The hardware decoder stalled (7 s of video in 12 s) and software decoding played smoothly in one test each. YouTube's mobile site serves 360p in Brave (measured 640x360), so the tile hands YouTube videos to SmartTube.
- **Startup.** Brave shows a notice that it loads flags from a command-line file, and may ask to become the default browser.

### Switches

`brave-flags.sh` sets them. Brave reads them only while it is the Android debug app, which the script sets and `--clear` removes. They survived one reboot. Current set:

```bash
bash brave-flags.sh "--use-angle=vulkan --enable-features=Vulkan --enable-spatial-navigation --disable-accelerated-video-decode --force-renderer-accessibility"
```

None of them turns off a protection: no sandbox or web-security switch. `--force-renderer-accessibility` is for the pointer: without it Brave accepts an accessibility click on a web link and then does nothing.

Tested and not helpful: `--disable-gpu-rasterization`, `--disable-features=AndroidSurfaceControl`, `--in-process-gpu`, `--num-raster-threads=1 --disable-partial-raster --disable-zero-copy`. With `--use-gl=egl` Brave did not start.

When testing over adb, quote URLs twice (`-d "'http://...'"`): the TV's shell cuts an unquoted URL at the first `&`.

### The tile: app-list entry, start page, pointer

Brave declares no TV launcher entry, so it does not appear among the TV apps. `brave-tile/` builds an unofficial launcher app, labelled Brave with Brave's lion, that does:

- **Start page.** A box for an address or a search (Brave Search), a few links and "Continua in Brave". Typing happens here, with the TV keyboard.
- **Pointer.** The accessibility service "Cursore per Brave" (`CursorService.java`). It works only while Brave has the screen and no keyboard is up. The arrows move it (a press is a small step, holding speeds up), OK clicks where it points, including Brave's top bar, Shields, tabs and menu, pushing past the top or bottom edge scrolls, and holding Back shows or hides it. A short Back is still Back.
  - This TV has no touchscreen, so Android cancels injected touches (`dispatchGesture`). The pointer clicks through accessibility instead: the smallest clickable element under it gets `ACTION_CLICK`, and scrolling uses `ACTION_SCROLL_FORWARD`/`BACKWARD`. Touch gestures are used only on devices that declare a touchscreen.
  - Holding OK toggles full screen. A video player hides its controls a moment after they show, and the pointer is no mouse that keeps them up. The hold finds the player's button by its label ("Enter full screen", "Schermo intero" and a few more languages) and presses it. If the controls are hidden, it presses "Show player controls" first, then looks for the button every 150 ms for 1.5 s. Tested on YouTube's mobile site with the controls showing; the hidden-controls path showed them, but the first version gave up too early, and the retry version is untested there.
  - Smallest, not deepest: a line of web text has a box as wide as the paragraph and covers the link beside it.
  - It logs neither keys nor screen text, and the app has no Internet permission.
  - Keys injected with `adb shell input` skip the accessibility key filter. To test over adb, the service takes a broadcast that only the shell (DUMP permission) can send: `adb shell am broadcast -a io.github.vidoluco.bravetv.TEST --ei key 23 --ei x 1855 --ei y 55` moves the pointer and presses OK. Results go to logcat, tag `BraveCursor`.
  - Tested over adb: three-dot menu, address bar (keyboard opens), Shields panel, a GitHub page tab, a Wikipedia link, scrolling. Confirmed with the real remote.
- **YouTube goes to SmartTube.** When Brave's address bar shows a YouTube video (`watch`, Shorts, live, `youtu.be`) and is not being typed in, the service sends Brave back one page and opens the video in SmartTube, at the link's `t=` start time if there is one. Tested: a `watch?v=...&t=290s` link opened in Brave played in SmartTube at 3840x2160 from 4:50. Not yet checked: which page Brave is left on.
- **Play Protect.** MATVT, an existing pointer app, was blocked as harmful and was not installed. The tile was not flagged.
- **TCL blocks the pointer from starting.** TCL's app boot manager refuses to bind the service: `callee_does't_have_OP_AUTO_START_permission`. The TV has no switch for it. Turning the service off and on in Accessibility while the tile app is open lets it start, likely until the next reboot. After `adb install -r`, launching the tile app right away usually lets it bind again. The lasting fix is a permission only for this app, for the TV's owner to grant:

  ```bash
  adb -s "$TV" shell appops set io.github.vidoluco.bravetv APP_AUTO_START allow
  ```

Build and install (JDK 17+, Android build-tools 34, platform 34 `android.jar`):

```bash
JAVA_HOME=<jdk> BT=<build-tools dir> AJ=<android.jar> bash brave-tile/build.sh
adb -s "$TV" install -r brave-tile/brave-tv.apk
```

The first build creates `brave-tile/.signing.keystore` and its password in `brave-tile/.signing.env`, both kept out of git. Keep them: an update must be signed with the same key, and whoever has it can update an app that holds accessibility rights. With build-tools 34, `d8` fails on anonymous and inner classes compiled by JDK 21, so the helper classes are top level.

### Brave updates

Brave came from its APK, so the Play Store never updates it. `update-brave.sh`:

- At most once every 30 days, compares the TV's Brave with the latest stable release of `brave/brave-browser`.
- If there is a newer one, downloads `BraveMonoarm.apk` and checks its SHA-256 against the digest GitHub publishes.
- Installs with `adb install -r`, which Android accepts only when the APK is signed with the same key as the installed Brave.
- Skips when the TV is off or Brave is on screen, and tries again the next night.
- Writes `update-brave.log` and shows a macOS notification.
- `--force` checks now; `--reinstall-test` also reinstalls the same version, to test every step (one run: 40 s).

A launchd job runs it every night at 03:30, or at the next wake:

```bash
sed "s#__DIR__#$PWD#g" launchd/io.github.vidoluco.tv-brave-update.plist > ~/Library/LaunchAgents/io.github.vidoluco.tv-brave-update.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.github.vidoluco.tv-brave-update.plist
```

macOS asks for the Local Network permission per app. An adb server started by the job had none and could not reach the TV ("TV not reachable" in the log). Allow `adb` in System Settings, Privacy & Security, Local Network. Until then the job only works while an adb server started from a terminal is running. The script stops any adb server it started itself.

## YouTube on this TV

SmartTube (`org.smarttube.stable`, from `yuliskov/SmartTube` releases, armeabi-v7a, checksum checked) is installed. In one test it played a 4K video with the hardware decoder at 3840x2160. The picture itself cannot be seen in adb screenshots. Signing in there gives a third-party app access to the YouTube account.

## Racing Karts on this TV

[Racing Karts](https://github.com/vidoluco/racing-karts) plays on a computer, mirrored to the TV with AirPlay. Natively the race did not run well:

- The game opens one WebGL context per kart turntable. Android allows fewer contexts than a desktop browser, and the oldest, the race's, is dropped. `racing-karts-tv.patch` draws all turntables through one shared context, which fixes it.
- With the patch, the race shows in the TCL browser but runs at about 10 fps at 640x360 in the patch's TV quality mode. That is too slow to play.
- In Brave the GPU process died during the race.

The patch is kept here only. The game itself is unchanged.
