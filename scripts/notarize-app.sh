#!/bin/zsh
set -euo pipefail

TARGET_PATH="${1:-}"

if [[ -z "$TARGET_PATH" || ! -e "$TARGET_PATH" ]]; then
  echo "Usage: $0 <path-to-app-or-dmg>" >&2
  exit 1
fi

auth_args=()
if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  auth_args=(--keychain-profile "$NOTARYTOOL_PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  auth_args=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD")
elif [[ -n "${APPLE_API_KEY_PATH:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" ]]; then
  auth_args=(--key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID")
else
  echo "No notarization credentials found. Set NOTARYTOOL_PROFILE, or Apple ID/team/app-specific password, or App Store Connect API key env vars." >&2
  exit 1
fi

submit_path="$TARGET_PATH"
temp_dir=""

cleanup() {
  if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
    rm -rf "$temp_dir"
  fi
}
trap cleanup EXIT

if [[ "$TARGET_PATH" == *.app ]]; then
  temp_dir="$(mktemp -d)"
  submit_path="$temp_dir/$(basename "$TARGET_PATH").zip"
  ditto -c -k --keepParent "$TARGET_PATH" "$submit_path"
fi

xcrun notarytool submit "$submit_path" --wait "${auth_args[@]}"

if [[ "$TARGET_PATH" == *.app || "$TARGET_PATH" == *.dmg || "$TARGET_PATH" == *.pkg ]]; then
  xcrun stapler staple -v "$TARGET_PATH"
fi
