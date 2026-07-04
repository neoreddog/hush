#!/bin/zsh
# Builds Hush.app and packages it into a custom drag-and-drop DMG installer:
# a Mist-colored window with the Hush icon on the left, an arrow, and the
# Applications folder on the right — drag across to install.
# Usage: scripts/make-dmg.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)}"
VOLNAME="Hush"
DMG="build/Hush-$VERSION.dmg"
RW="build/Hush-rw.dmg"
STAGING="build/dmg-staging"
BG="$STAGING/.background"

./scripts/build-app.sh release

# --- Stage contents ------------------------------------------------------
rm -rf "$STAGING" "$DMG" "$RW"
mkdir -p "$BG"
cp -R build/Hush.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Render the window background at 1x and 2x, then fold them into one
# Hi-DPI TIFF so the art stays crisp on Retina displays.
swift scripts/dmg-background.swift "$BG/bg-1x.png" 1
swift scripts/dmg-background.swift "$BG/bg-2x.png" 2
tiffutil -cathidpicheck "$BG/bg-1x.png" "$BG/bg-2x.png" -out "$BG/background.tiff"
rm -f "$BG/bg-1x.png" "$BG/bg-2x.png"

# --- Create a writable DMG we can dress up -------------------------------
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" \
    -fs HFS+ -format UDRW -ov "$RW"

MOUNT_DIR="/Volumes/$VOLNAME"
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep -E '/Volumes/' | awk '{print $1}')
sleep 2

# --- Arrange the window with Finder --------------------------------------
osascript <<EOF
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 840, 520}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128
        set text size of opts to 13
        set background picture of opts to file ".background:background.tiff"
        set position of item "Hush.app" of container window to {192, 172}
        set position of item "Applications" of container window to {448, 172}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Give the volume the Hush icon, last, after Finder has finished writing its
# metadata so it isn't clobbered. (hdiutil's -srcfolder drops .VolumeIcon.icns,
# so it must be written onto the mounted volume here; both the icns creator
# type and the volume's custom-icon attribute are required for Finder to show
# it.)
cp branding/app-icon/Hush.icns "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR"

sync
hdiutil detach "$DEVICE" >/dev/null

# --- Compress to the final read-only DMG ---------------------------------
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG"

rm -rf "$STAGING" "$RW"
echo "Created $DMG"
