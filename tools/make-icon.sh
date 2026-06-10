#!/bin/bash
# 由 make-icon.swift 生成 1024 PNG → 各尺寸 iconset → Resources/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
PNG="$TMP/icon_1024.png"
swift tools/make-icon.swift "$PNG"

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16     "$PNG" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$PNG" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$PNG" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$PNG"                "$ICONSET/icon_512x512@2x.png"

mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
rm -rf "$TMP"
echo "==> 生成 Resources/AppIcon.icns"
