# Hush brand assets

Source of truth: `brand-guidelines.html` (open in a browser).

- `app-icon/` — macOS app icon. `Hush.icns` is ready to drop into an Xcode asset catalog or `iconutil`-based build; `Hush.iconset/` and the 1024px master PNG/SVG are included for regenerating it.
- `menu-bar/` — status bar glyph, exported at 16/32/48px (@1x/@2x/@3x). `hush-menubar-idle*` is a template image (black shape, alpha-only — macOS tints it automatically for light/dark menu bars) for the "all quiet" state. `hush-menubar-active*` is the full-color mark for when Hush is actively quieting something down.
- `mark/` — the standalone color mark (equalizer bars) at several raster sizes, plus source SVG, for use outside the menu bar (about screens, marketing, etc).
- `wordmark/` — "Hush" logotype set in the display serif, for light and dark backgrounds.

All PNGs have transparent backgrounds. All SVGs are the editable sources — regenerate PNGs from these if the palette or mark ever changes.
