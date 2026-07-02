#!/bin/zsh
# Builds Hush.app from the Swift package.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/Hush"
APP="build/Hush.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Hush"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Brand assets: app icon + menu bar glyphs (idle template, active color).
cp branding/app-icon/Hush.icns "$APP/Contents/Resources/Hush.icns"
for scale in "" "@2x" "@3x"; do
    cp "branding/menu-bar/hush-menubar-idle$scale.png" "$APP/Contents/Resources/"
    cp "branding/menu-bar/hush-menubar-active$scale.png" "$APP/Contents/Resources/"
done

# Ad-hoc sign so SMAppService (Launch at Login) works.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Install with: cp -R $APP /Applications/"
