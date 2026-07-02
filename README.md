# Hush

*A creative person's life saver.*

A lightweight macOS menu bar app that notices when **Adobe Crash Processor**
starts working overtime in the background and quietly brings it back down.

## How it works

- Polls the process list every 5 seconds (via `sysctl`, no shelling out).
- When the target process is found, its CPU is capped by duty-cycling it
  with `SIGSTOP`/`SIGCONT` in 100 ms windows — the same technique as
  `cpulimit`. No root, kernel extensions, or dependencies required.
- If the process exits or its PID is reused by a different process, the
  throttler detaches and sends a final `SIGCONT`, so nothing is ever left
  suspended. The same cleanup runs on quit, `SIGTERM`, and `SIGINT`.

## The menu

- **Status line** — "All quiet." or "Working on it.", set in the brand
  serif. The menu bar glyph switches from the template idle mark to the
  full-color settling bars while Hush is actively quieting something.
- **Allowance slider** — how much of the Mac the watched task is allowed
  to use (5–95% in 5% steps, default 20%). Applies immediately, persists.
- **Advanced ▸ Watched Process** — pick a different process to watch,
  from a busiest-first list of running processes or by typing a name.
- **Advanced ▸ Start Automatically at Login** — registers via
  `SMAppService` (requires running from `/Applications`, not the bare
  binary).

The poll interval is configurable via defaults:

```sh
defaults write com.hush.app pollIntervalSeconds 10
```

## Branding

All brand assets and guidelines live in `branding/` — see
`branding/brand-guidelines.html` for the palette (deep plum family),
typography (Iowan Old Style display serif), and voice ("explain the
feeling, never the mechanism"). User-facing copy never says CPU,
process, throttle, or kill.

## Build

```sh
./scripts/build-app.sh          # → build/Hush.app
cp -R build/Hush.app /Applications/
open /Applications/Hush.app
```

Requires macOS 13+ and Xcode command line tools. See RELEASE.md for
building the distributable DMG.
