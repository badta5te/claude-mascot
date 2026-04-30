#!/bin/sh
# Build ClaudeMascot.app from Swift sources + flat PNG resources.
set -eu

REPO="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO/ClaudeMascot"
BUILD="$REPO/build"
APP="$BUILD/ClaudeMascot.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
EXE="$MACOS/ClaudeMascot"

rm -rf "$BUILD"
mkdir -p "$MACOS" "$RES"

xcrun swiftc \
  -O \
  -target "$(uname -m)-apple-macos11.0" \
  -framework AppKit \
  -o "$EXE" \
  "$SRC"/*.swift

cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
cp "$SRC/Resources/"*.png "$RES/"
[ -f "$SRC/Resources/AppIcon.icns" ] && cp "$SRC/Resources/AppIcon.icns" "$RES/"

codesign --force --sign - "$APP" >/dev/null

echo "built $APP"
