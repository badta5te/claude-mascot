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

# Universal binary: build each slice, then lipo.
mkdir -p "$BUILD/slices"
for ARCH in arm64 x86_64; do
  xcrun swiftc \
    -O \
    -target "$ARCH-apple-macos11.0" \
    -framework AppKit \
    -o "$BUILD/slices/ClaudeMascot-$ARCH" \
    "$SRC"/*.swift
done
lipo -create -output "$EXE" "$BUILD/slices/ClaudeMascot-arm64" "$BUILD/slices/ClaudeMascot-x86_64"
rm -rf "$BUILD/slices"

cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
cp "$SRC/Resources/"*.png "$RES/"
[ -f "$SRC/Resources/AppIcon.icns" ] && cp "$SRC/Resources/AppIcon.icns" "$RES/"

# Hook scripts ship inside the app — the app installs them on first launch.
mkdir -p "$RES/hooks"
cp "$REPO/hooks/"*.sh "$RES/hooks/"
chmod 0755 "$RES/hooks/"*.sh

codesign --force --sign - "$APP" >/dev/null

echo "built $APP"
