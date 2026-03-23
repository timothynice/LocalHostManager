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
- Create and push a `v*` tag when you are ready to publish a release
- Decide whether you also want a Homebrew cask or Sparkle-based auto-update flow

## Apple signing checklist

Public GitHub releases need a `Developer ID Application` certificate. An `Apple Development` certificate is not enough for outside-the-App-Store distribution.

Recommended setup:

1. Create or download a `Developer ID Application` certificate for your Apple Developer team.
2. Export the certificate and private key from Keychain Access as a password-protected `.p12`.
3. Base64-encode that `.p12` for the `APPLE_DEVELOPER_ID_CERT_P12_BASE64` GitHub secret.
4. Add the certificate password, signing identity string, team ID, and notarization credentials as GitHub repository secrets.

To export the certificate from Keychain Access:

1. Open Keychain Access.
2. Select the `Developer ID Application` certificate together with its private key.
3. Choose `File > Export Items`.
4. Save it as a password-protected `.p12`.

You can then base64-encode it with:

```bash
base64 -i developer-id-cert.p12 | pbcopy
```
