#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/release-config.sh"

has_notary_credentials() {
  [[ -n "${NOTARYTOOL_PROFILE:-}" ]] \
    || [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]] \
    || [[ -n "${APPLE_API_KEY_PATH:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" ]]
}

rm -f "$ZIP_PATH" "$DMG_PATH" "$CHECKSUM_PATH"

"$ROOT_DIR/scripts/build-app.sh"

if has_notary_credentials; then
  if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    echo "Notarization credentials are present, but CODESIGN_IDENTITY is not set." >&2
    exit 1
  fi

  "$ROOT_DIR/scripts/notarize-app.sh" "$APP_DIR"
fi

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

STAGING_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_DISPLAY_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if has_notary_credentials; then
  "$ROOT_DIR/scripts/notarize-app.sh" "$DMG_PATH"
fi

shasum -a 256 "$ZIP_PATH" "$DMG_PATH" > "$CHECKSUM_PATH"

echo "Created:"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
echo "  $CHECKSUM_PATH"
