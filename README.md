# LocalHostManager

Native macOS menu bar app for spotting local dev servers by project name and port, then opening or stopping them.

## What it does

- Scans your user-owned listening TCP processes with `lsof` and `ps`
- Detects likely dev servers such as Vite, Next.js, Rails, Django, Flask, Phoenix, and simple localhost servers
- Infers project names from the working directory and common manifest files
- Shows each server in a clean menu bar popover with:
  - project name
  - port
  - stack / PID
  - working directory
  - open and stop controls
- Supports launch at login

## Local development

```bash
cd /Users/TimNice/Development/LocalHostManager
swift run
```

## Build the app

```bash
cd /Users/TimNice/Development/LocalHostManager
./scripts/build-app.sh
open dist/LocalHostManager.app
```

## Create release artifacts

```bash
cd /Users/TimNice/Development/LocalHostManager
./scripts/package-release.sh
```

For signing, notarization, and GitHub release setup, see [docs/DISTRIBUTION.md](/Users/TimNice/Development/LocalHostManager/docs/DISTRIBUTION.md).
