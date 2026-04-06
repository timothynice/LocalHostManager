# Studi0Ports

Native macOS menu bar app for spotting local dev servers by project name and port, then opening or stopping them.

## Distribution model

This project is currently distributed as source code, not as a signed prebuilt app. The intended install flow is: clone the repo, build locally on your own Mac, and run the generated menu bar app.

## Requirements

- macOS 13 or later
- Xcode or Xcode Command Line Tools with Swift

## Quick start

```bash
git clone https://github.com/timothynice/LocalHostManager.git
cd LocalHostManager
./scripts/dev-setup.sh
```

That command builds `dist/Studi0Ports.app` and opens it.

To install it into `/Applications`:

```bash
./scripts/install-app.sh
```

If you want to run it without creating the app bundle:

```bash
swift run
```

## What it does

- Scans your user-owned listening TCP processes with `lsof` and `ps`
- Detects likely dev servers such as Vite, Next.js, Rails, Django, Flask, Phoenix, and simple localhost servers
- Infers project names from the working directory and common manifest files
- Shows each server in a clean menu bar popover with project name, port, stack, PID, and working directory
- Lets you open a server in the browser or stop it directly from the menu bar
- Supports launch at login, with an unsigned-build fallback for local source builds

## Useful commands

Build the local app bundle:

```bash
./scripts/build-app.sh
```

Build and install the app into `/Applications`:

```bash
./scripts/install-app.sh
```

Create optional local binary artifacts for your own testing:

```bash
./scripts/package-release.sh
```

For the source-first distribution approach and the optional future binary-release path, see [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md).
