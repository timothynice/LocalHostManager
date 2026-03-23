#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/release-config.sh"

swift build -c "$BUILD_CONFIGURATION" --package-path "$ROOT_DIR"

rm -rf "$APP_DIR" "$ICONSET_DIR" "$ICON_ICNS_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$ICONSET_DIR"
xcrun iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS_PATH"

cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
cp "$ICON_ICNS_PATH" "$RESOURCES_DIR/AppIcon.icns"

cat > "$INFO_PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS_VERSION</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

xattr -cr "$APP_DIR" 2>/dev/null || true

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign \
    --force \
    --sign "$CODESIGN_IDENTITY" \
    --deep \
    --options runtime \
    --timestamp \
    "$APP_DIR"

  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
fi

touch "$APP_DIR"
echo "Created $APP_DIR"
