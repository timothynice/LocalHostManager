# Distribution

LocalHostManager is set up to ship outside the Mac App Store as a signed and notarized `.app`, `.zip`, and `.dmg`.

## What the repo now handles

- Versioned app bundle generation
- Generated `.icns` app icon
- Optional Developer ID signing
- Optional notarization with `notarytool`
- `.zip` and `.dmg` release artifacts
- SHA-256 checksum file
- GitHub Actions release workflow
- Native launch-at-login via `SMAppService.mainApp` for signed builds, with a legacy fallback for unsigned/dev builds

## Local release commands

Build an unsigned app bundle:

```bash
./scripts/build-app.sh
```

Build release artifacts:

```bash
./scripts/package-release.sh
```

Build, sign, and notarize release artifacts:

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export APPLE_TEAM_ID="TEAMID"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./scripts/package-release.sh
```

Artifacts land in `dist/`:

- `LocalHostManager-<version>.zip`
- `LocalHostManager-<version>.dmg`
- `LocalHostManager-<version>-sha256.txt`

## GitHub Actions secrets

To produce notarized GitHub releases, add these repository secrets:

- `APPLE_DEVELOPER_ID_CERT_P12_BASE64`
- `APPLE_DEVELOPER_ID_CERT_PASSWORD`
- `APPLE_DEVELOPER_ID_IDENTITY`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

If those secrets are missing, the workflow still builds release artifacts, but they will not be signed or notarized.

## Remaining manual work

- Enroll in the Apple Developer Program if you have not already
- Create/export a `Developer ID Application` certificate as `.p12`
- Create an app-specific password for notarization, or switch the scripts to App Store Connect API keys
- Push the repo to GitHub and create/push a `v*` tag
- Decide whether you also want a Homebrew cask or Sparkle-based auto-update flow
