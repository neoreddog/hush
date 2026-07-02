#!/bin/zsh
# Builds Hush.app from the Swift package as a universal binary, so it runs
# natively on both Apple Silicon and Intel Macs.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"

swift build -c "$CONFIG" --triple arm64-apple-macosx13.0
swift build -c "$CONFIG" --triple x86_64-apple-macosx13.0

ARM_BIN="$(swift build -c "$CONFIG" --triple arm64-apple-macosx13.0 --show-bin-path)/Hush"
X86_BIN="$(swift build -c "$CONFIG" --triple x86_64-apple-macosx13.0 --show-bin-path)/Hush"

APP="build/Hush.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/Hush" "$ARM_BIN" "$X86_BIN"
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
