#!/bin/zsh
# Builds Tabinator.app and packages it into a drag-and-drop DMG installer.
# Usage: scripts/make-dmg.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)}"
DMG="build/Tabinator-$VERSION.dmg"
STAGING="build/dmg-staging"

./scripts/build-app.sh release

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R build/Tabinator.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "Tabinator $VERSION" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG"

rm -rf "$STAGING"
echo "Created $DMG"
