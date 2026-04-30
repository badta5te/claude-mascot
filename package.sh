#!/bin/sh
# Build a release archive: ClaudeMascot.app + hooks + installer + INSTALL.md.
# Output: dist/ClaudeMascot-<version>.tar.gz
set -eu

REPO="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$REPO/ClaudeMascot/Info.plist" 2>/dev/null || echo 0.1.0)"
DIST="$REPO/dist"
STAGE="$DIST/ClaudeMascot-$VERSION"

"$REPO/build.sh"

rm -rf "$STAGE"
mkdir -p "$STAGE"

cp -R "$REPO/build/ClaudeMascot.app" "$STAGE/"
cp -R "$REPO/hooks"                  "$STAGE/"
cp -R "$REPO/scripts"                "$STAGE/"
cp    "$REPO/INSTALL.md"             "$STAGE/"

ARCHIVE="$DIST/ClaudeMascot-$VERSION.tar.gz"
rm -f "$ARCHIVE"
tar -C "$DIST" -czf "$ARCHIVE" "ClaudeMascot-$VERSION"

echo "packaged $ARCHIVE"
ls -lh "$ARCHIVE"
