#!/bin/bash
# Build brave-tv.apk. Needs a JDK, Android build-tools and an android.jar:
#   JAVA_HOME=... BT=<build-tools dir> AJ=<android.jar> bash build.sh
set -euo pipefail
cd "$(dirname "$0")"
: "${JAVA_HOME:?set JAVA_HOME}" "${BT:?set BT to a build-tools dir}" "${AJ:?set AJ to android.jar}"
export PATH="$JAVA_HOME/bin:$PATH"
OUT=build
rm -rf "$OUT" res; mkdir -p "$OUT/classes" res/drawable-xhdpi res/mipmap-xxxhdpi
cp -R res-src/. res/

# Brave's lion is Brave's trademark, so it is not kept in this repo: it is fetched from brave/brave-core at a fixed
# commit, checked, and used only for the local build.
LOGO=art/brave-lion-256.png
LOGO_URL=https://raw.githubusercontent.com/brave/brave-core/7f753224eb265f802cf5d91f88ad733cfe8cdad4/app/theme/brave/product_logo_256.png
LOGO_SHA256=9d9a83ee4d49f2b9042d8f71989f66effcef12736330b81456523828045dc456
mkdir -p art
[ -f "$LOGO" ] || curl -fsSL -o "$LOGO" "$LOGO_URL"
[ "$(shasum -a 256 "$LOGO" | cut -d' ' -f1)" = "$LOGO_SHA256" ] || { echo "logo checksum mismatch: $LOGO"; rm -f "$LOGO"; exit 1; }
swift art.swift res "$LOGO"
"$BT/aapt2" compile --dir res -o "$OUT/res.zip"
"$BT/aapt2" link -I "$AJ" --manifest AndroidManifest.xml --min-sdk-version 26 --target-sdk-version 34 \
  -o "$OUT/base.apk" "$OUT/res.zip"
javac -Xlint:-options -source 8 -target 8 -bootclasspath "$AJ" -classpath "$BT/core-lambda-stubs.jar" \
  -d "$OUT/classes" $(find src -name '*.java')
"$BT/d8" --release --lib "$AJ" --min-api 26 --output "$OUT" $(find "$OUT/classes" -name '*.class')
cp "$OUT/base.apk" "$OUT/unsigned.apk"
(cd "$OUT" && zip -q -j unsigned.apk classes.dex)
"$BT/zipalign" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

# A local key and its password, made once and kept out of git (.signing.keystore, .signing.env): an update must be
# signed with the same key, and whoever has it could ship an update to a service with accessibility rights.
KS=.signing.keystore
[ -f .signing.env ] && . ./.signing.env
if [ ! -f "$KS" ]; then
  TILE_KS_PASS="${TILE_KS_PASS:-$(openssl rand -hex 16)}"
  keytool -genkeypair -keystore "$KS" -storepass "$TILE_KS_PASS" -keypass "$TILE_KS_PASS" -alias tile \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Brave TV tile" >/dev/null
  echo "TILE_KS_PASS=$TILE_KS_PASS" > .signing.env; chmod 600 .signing.env "$KS"
fi
export TILE_KS_PASS; : "${TILE_KS_PASS:?the keystore exists but .signing.env with TILE_KS_PASS is missing}"
"$BT/apksigner" sign --ks "$KS" --ks-pass env:TILE_KS_PASS --ks-key-alias tile --out brave-tv.apk "$OUT/aligned.apk"
"$BT/apksigner" verify brave-tv.apk && echo "built $(pwd)/brave-tv.apk"
