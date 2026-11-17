#!/usr/bin/env bash
# Build Bromite 108 (Chromium 108) for Android 4.4 KitKat x86.
#
# REQUISITOS (en la máquina donde se ejecute):
#   - 100 GB libres en disco, 16 GB RAM, Linux x86_64
#   - Python 3, git, curl, unzip
#   - Java 17 (JDK) para las herramientas de Android
#
# Uso:
#   ./build-bromite-108.sh /ruta/con/espacio
#
# NOTA: este script NO se puede ejecutar en la tablet TR10RS1 ni en el
# eMMC de 29 GB de la máquina actual. Está preparado para un runner grande
# (self-hosted o GitHub larger-runner de 150 GB).
set -euo pipefail

ROOT="${1:-$PWD/bromite108-build}"
PATCH_DIR="$(cd "$(dirname "$0")/patches/kitkat-108" && pwd)"
mkdir -p "$ROOT"
cd "$ROOT"

echo "==> Espacio libre al empezar:"
df -h .

# 1. depot_tools
if [ ! -d depot_tools ]; then
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi
export PATH="$PWD/depot_tools:$PATH"

# 2. Chromium 108 source + Bromite patches
if [ ! -d src ]; then
  fetch --no-history --nohooks android
  cd src
  git checkout 108.0.5359.156
  gclient sync --nohooks --no-history -D
else
  cd src
fi

# 3. Bromite's own patch set from v83 (the last KitKat-compatible release).
#    These are privacy/adblock patches; the KitKat-specific bit is the
#    minSdk revert below. Adapt conflicts for 108 with --3way.
BROMITE_PATCH_URL="https://github.com/bromite/bromite/archive/refs/tags/83.0.4103.119.tar.gz"
curl -sL "$BROMITE_PATCH_URL" -o /tmp/bromite83.tar.gz
mkdir -p /tmp/bromite83
tar xzf /tmp/bromite83.tar.gz -C /tmp/bromite83 --strip-components=1
if [ -f /tmp/bromite83/build/bromite_patches_list.txt ]; then
  while read -r p; do
    [ -z "$p" ] && continue
    f="/tmp/bromite83/build/patches/$p"
    [ -f "$f" ] || continue
    echo "  aplicando $p"
    git apply --3way "$f" || echo "  AVISO: conflicto en $p (revisar a mano)"
  done < /tmp/bromite83/build/bromite_patches_list.txt
fi

# 4. KitKat patches: restore minSdk 19 in the build system.
git apply --3way "$PATCH_DIR/01-revert-minsdk-19-to-21.patch" || {
  echo "ERROR: no se pudo aplicar el parche de minSdk"; exit 1;
}

# 5. GN args: x86 de 32 bits, API 19, build mínimo.
mkdir -p out/kitkat-x86
cat > out/kitkat-x86/args.gn <<'EOF'
target_os = "android"
target_cpu = "x86"
is_debug = false
is_official_build = true
symbol_level = 0
exclude_unwind_tables = true
android_min_sdk_version = 19
default_min_sdk_version = 19
disable_android_lint = true
use_errorprone_java_compiler = false
enable_vr = false
enable_vulkan = false
chrome_pgo_phase = 0
EOF
gn gen out/kitkat-x86

# 6. Compilar (esto tarda 1-3 h).
autoninja -C out/kitkat-x86 chrome_public_apk

echo "==> APK resultante:"
ls -lh out/kitkat-x86/apks/ChromePublic.apk
echo "==> Verificar minSdk:"
aapt dump badging out/kitkat-x86/apks/ChromePublic.apk | head -3
