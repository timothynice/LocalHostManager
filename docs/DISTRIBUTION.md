# Distribution

Studi0 Ports is currently source-first. The recommended way to share it is to publish the repo and have developers build it locally on their own Macs.

## Recommended install flow

Users should install it like this:

```bash
git clone https://github.com/timothynice/LocalHostManager.git
cd LocalHostManager
./scripts/install-app.sh
```

That builds the app, installs `Studi0 Ports.app` into `/Applications`, and opens it.

If someone only wants a local bundle in `dist/` without installing it:

```bash
./scripts/dev-setup.sh
```

If someone only wants to run it directly from SwiftPM:

```bash
swift run
```

## Why this is the default path

- It matches the actual audience for this app: developers running local servers
- It avoids Apple signing and notarization work for now
- It keeps distribution simple: GitHub repo plus local build instructions
- The launch-at-login feature already has an unsigned-build fallback for local source builds

## Maintainer tools still in the repo

These remain available if you want them:

- `./scripts/build-app.sh` builds a local `.app`
- `./scripts/package-release.sh` creates `.zip` and `.dmg` artifacts for local testing
- `.github/workflows/release.yml` is now an optional manual binary-build workflow, not the default distribution path

## Optional future binary release path

If you later decide to distribute prebuilt macOS downloads, the existing scripts can still support that. At that point you would need:

- a `Developer ID Application` certificate exported as `.p12`
- notarization credentials
- the GitHub repository secrets expected by the workflow

The secrets used by the optional workflow are:

- `APPLE_DEVELOPER_ID_CERT_P12_BASE64`
- `APPLE_DEVELOPER_ID_CERT_PASSWORD`
- `APPLE_DEVELOPER_ID_IDENTITY`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

If you go back to binary distribution later, the rough process is:

1. Create or download a `Developer ID Application` certificate for your Apple Developer team.
2. Export the certificate and private key from Keychain Access as a password-protected `.p12`.
3. Base64-encode that `.p12` for the GitHub secret.
4. Add the signing and notarization secrets to the repo.
5. Run the manual workflow or create a tagged release when you are ready.
