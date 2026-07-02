# Tabinator

A lightweight macOS menu bar app that watches for **Adobe Crash Processor**
and caps its CPU usage.

## How it works

- Polls the process list every 5 seconds (via `sysctl`, no shelling out).
- When the target process is found, its CPU is capped by duty-cycling it
  with `SIGSTOP`/`SIGCONT` in 100 ms windows — the same technique as
  `cpulimit`. No root, kernel extensions, or dependencies required.
- If the process exits or its PID is reused by a different process, the
  throttler detaches and sends a final `SIGCONT`, so nothing is ever left
  suspended. The same cleanup runs on quit, `SIGTERM`, and `SIGINT`.

## Menu bar controls

- **Maximum CPU slider** — drag to set the cap (5–95% in 5% steps,
  default 20%). Applies immediately and persists across restarts.
- **Start Automatically at Login** — registers via `SMAppService`
  (requires running from the built `.app` bundle, not the bare binary).
- **Advanced ▸ Watched Process** — pick a different process to limit,
  from a busiest-first list of running processes or by typing a name.

The menu bar gauge turns sea-green while a process is actively being
limited. The poll interval is configurable via defaults:

```sh
defaults write com.tabinator.app pollIntervalSeconds 10
```

## Build

```sh
./scripts/build-app.sh          # → build/Tabinator.app
cp -R build/Tabinator.app /Applications/
open /Applications/Tabinator.app
```

Requires macOS 13+ and Xcode command line tools.
