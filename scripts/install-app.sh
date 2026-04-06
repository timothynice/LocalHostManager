#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/release-config.sh"

TARGET_APP="/Applications/$APP_BUNDLE_NAME.app"

"$ROOT_DIR/scripts/build-app.sh"

rm -rf "$TARGET_APP"
ditto "$APP_DIR" "$TARGET_APP"
xattr -cr "$TARGET_APP" 2>/dev/null || true

echo "Installed $TARGET_APP"

if [[ "${NO_OPEN:-0}" != "1" ]]; then
  open -n "$TARGET_APP"
fi
