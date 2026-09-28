#!/bin/bash
# 建置 FocusBar.app 並打包成 dist/FocusBar-<版本>.zip
# 用法：scripts/build-app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="FocusBar"
PLIST="Resources/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "==> 建置 release 執行檔"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "==> 產生 App 圖示"
ICONSET="$(mktemp -d)/AppIcon.iconset"
swift scripts/make-icon.swift "$ICONSET"
mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

echo "==> 組成 $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$PLIST" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> ad-hoc 簽章"
codesign -s - --deep --force "$APP"
codesign --verify --deep --strict "$APP"

echo "==> 壓縮"
ZIP="$DIST/$APP_NAME-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "完成：$APP"
echo "壓縮檔：$ZIP"
