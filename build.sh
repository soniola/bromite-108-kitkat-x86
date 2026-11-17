#!/usr/bin/env bash
# Rebuild "Bromite KitKat x86" from the upstream x86 APK.
# No Gradle, no Chromium toolchain needed: only apktool + aapt/apksigner.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

JRE=/home/alejandro/android-tools/jdk-17.0.21+9-jre
ANDROID_TOOLS=/home/alejandro/android-tools/android-14
export PATH="$JRE/bin:$PATH"

BASE=bromite-83.0.4103.119-x86.apk
WORK=bromite83
UNSIGNED=bromite-kitkat-x86-unsigned.apk
ALIGNED=bromite-kitkat-x86-aligned.apk
OUT=bromite-kitkat-x86.apk
KEYSTORE=${KEYSTORE:-/home/alejandro/debug.keystore}
KS_PASS=${KS_PASS:-android}

if [ ! -f "$BASE" ]; then
  echo "Falta $BASE. Descárgalo de:"
  echo "  https://github.com/bromite/bromite/releases/tag/83.0.4103.119"
  exit 1
fi

# 1. Decompile (resources + smali; native libs are copied verbatim).
"$JRE/bin/java" -jar apktool.jar decode -f "$BASE" -o "$WORK"

# 2. KitKat-specific changes (see README_KITKAT.md):
#    - Visible app label, so it can coexist with a stock Bromite install.
#    - minSdk is already 19 upstream; the source tree keeps it that way.
sed -i \
  's|<string name="APKTOOL_DUMMYVAL_0x7f130170">Bromite</string>|<string name="APKTOOL_DUMMYVAL_0x7f130170">Bromite KitKat x86</string>|' \
  "$WORK/res/values/strings.xml"

grep -q 'minSdkVersion: 19' "$WORK/apktool.yml" || {
  echo "ERROR: el APK base ya no es compatible con API 19"; exit 1;
}

# 3. Rebuild, align and sign with the user's key (so Play Store never
#    replaces it with a Lollipop-only Bromite on the tablet).
"$JRE/bin/java" -jar apktool.jar build "$WORK" -o "$UNSIGNED"
"$ANDROID_TOOLS/zipalign" -f -p 4 "$UNSIGNED" "$ALIGNED"
"$ANDROID_TOOLS/apksigner" sign \
  --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" \
  --out "$OUT" "$ALIGNED"
"$ANDROID_TOOLS/apksigner" verify "$OUT"

echo "OK -> $HERE/$OUT"
"$ANDROID_TOOLS/aapt" dump badging "$OUT" | head -3
