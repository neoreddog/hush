# Releasing Hush

## TL;DR

```sh
# 1. Bump the version in Resources/Info.plist (CFBundleShortVersionString
#    and CFBundleVersion), commit, and tag:
git tag v1.1

# 2. Build the drag-and-drop installer:
./scripts/make-dmg.sh

# 3. Ship build/Hush-<version>.dmg
```

The DMG opens with `Hush.app` next to an `Applications` shortcut —
users install by dragging the app onto it.

## What the scripts do

- `scripts/build-app.sh` — compiles the Swift package in release mode,
  assembles `build/Hush.app` (binary + `Resources/Info.plist`), and
  ad-hoc codesigns it. The `.app` bundle is required for Launch at Login
  (`SMAppService`) to work.
- `scripts/make-dmg.sh [version]` — runs the build, stages the app with a
  symlink to `/Applications`, and packs it into a compressed DMG with
  `hdiutil`. The version defaults to `CFBundleShortVersionString` from
  Info.plist.

## Version bumping

Edit `Resources/Info.plist` before building:

- `CFBundleShortVersionString` — the user-facing version (e.g. `1.1`).
- `CFBundleVersion` — a monotonically increasing build number.

## Gatekeeper: the ad-hoc signing caveat

The scripts sign with an **ad-hoc** signature (`codesign --sign -`). That
is fine for personal use and direct sharing, but the app is not notarized,
so on another Mac downloaded copies are quarantined and Gatekeeper will
refuse to open them with a double-click. Recipients must either:

- Right-click the app → **Open** → **Open** (once), or
- `xattr -dr com.apple.quarantine /Applications/Hush.app`

### Proper signing + notarization (optional)

For frictionless distribution you need a paid Apple Developer account:

```sh
# Sign with your Developer ID instead of ad-hoc
# (edit build-app.sh, or re-sign the built app):
codesign --force --options runtime \
    --sign "Developer ID Application: Your Name (TEAMID)" \
    build/Hush.app

./scripts/make-dmg.sh

# Notarize the DMG (one-time: xcrun notarytool store-credentials)
xcrun notarytool submit build/Hush-<version>.dmg \
    --keychain-profile "notary" --wait
xcrun stapler staple build/Hush-<version>.dmg
```

## Publishing on GitHub (optional)

```sh
git push --tags
gh release create v1.1 build/Hush-1.1.dmg \
    --title "Hush 1.1" --notes "…"
```

## Sanity checklist before shipping

- [ ] Version bumped in `Resources/Info.plist`
- [ ] `./scripts/make-dmg.sh` completes without errors
- [ ] Mount the DMG: app + Applications shortcut both present
- [ ] Drag-install, launch from `/Applications`, confirm the menu bar
      icon appears and Launch at Login toggles without error
