#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/LocalHostManager.app"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Run 'xcode-select --install' and try again." >&2
  exit 1
fi

"$ROOT_DIR/scripts/build-app.sh"

echo "Built $APP_PATH"

if [[ "${NO_OPEN:-0}" != "1" ]]; then
  open "$APP_PATH"
fi
