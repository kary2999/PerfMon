#!/bin/bash
# PerfMon 打包脚本：Release 编译 → 组装 .app → 生成 zip + dmg。
# 产物统一输出到项目内 dist/ 目录。
set -euo pipefail

cd "$(dirname "$0")"
DIST="$(pwd)/dist"
VERSION="${1:-1.0}"

echo "==> Release 编译"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/PerfMonApp"

echo "==> 组装 PerfMon.app"
rm -rf "$DIST"; mkdir -p "$DIST"
APP="$DIST/PerfMon.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PerfMon"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PerfMon</string>
  <key>CFBundleDisplayName</key><string>PerfMon</string>
  <key>CFBundleIdentifier</key><string>vip.maskex.perfmon</string>
  <key>CFBundleExecutable</key><string>PerfMon</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
echo "APPL????" > "$APP/Contents/PkgInfo"
codesign --force --deep --sign - "$APP"

echo "==> 打 ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/PerfMon-$VERSION.zip"

echo "==> 打 DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "PerfMon" -srcfolder "$STAGE" -ov -format UDZO "$DIST/PerfMon-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

echo "==> 完成，产物在 dist/："
ls -lh "$DIST"
