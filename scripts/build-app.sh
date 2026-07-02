#!/bin/zsh
# Builds Tabinator.app from the Swift package.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/Tabinator"
APP="build/Tabinator.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Tabinator"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so SMAppService (Launch at Login) works.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Install with: cp -R $APP /Applications/"
