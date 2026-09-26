#!/usr/bin/env bash
#
# Builds Lidless.app (via scripts/build.sh) and packages it into a
# drag-to-install .dmg: Lidless.app on the left, a shortcut to
# /Applications on the right. Prefers `create-dmg` when available (or
# installable via Homebrew); otherwise falls back to a plain `hdiutil` +
# AppleScript recipe that needs nothing beyond what macOS ships with.
#
# Usage:
#   scripts/build_dmg.sh
#
# Output:
#   dist/Lidless-<version>.dmg

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Lidless"
APP_PATH="$ROOT_DIR/build/Build/Products/Release/${APP_NAME}.app"
DIST_DIR="$ROOT_DIR/dist"
VERSION="$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "==> Building $APP_NAME.app"
"$ROOT_DIR/scripts/build.sh"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

# --- Volume icon: reuse the app's own icon so the mounted DMG doesn't show
# a generic disk glyph. Best-effort; skipped if iconutil isn't available. ---
VOLICON_PATH=""
if command -v iconutil >/dev/null 2>&1; then
    ICONSET_SRC="$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"
    ICONSET_TMP="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET_TMP"
    declare -A ICON_MAP=(
        ["icon_16x16.png"]="icon_16x16.png"
        ["icon_16x16@2x.png"]="icon_16x16@2x.png"
        ["icon_32x32.png"]="icon_32x32.png"
        ["icon_32x32@2x.png"]="icon_32x32@2x.png"
        ["icon_128x128.png"]="icon_128x128.png"
        ["icon_128x128@2x.png"]="icon_128x128@2x.png"
        ["icon_256x256.png"]="icon_256x256.png"
        ["icon_256x256@2x.png"]="icon_256x256@2x.png"
        ["icon_512x512.png"]="icon_512x512.png"
        ["icon_512x512@2x.png"]="icon_512x512@2x.png"
    )
    for name in "${!ICON_MAP[@]}"; do
        cp "$ICONSET_SRC/$name" "$ICONSET_TMP/${ICON_MAP[$name]}"
    done
    ICNS_PATH="$(mktemp -d)/AppIcon.icns"
    if iconutil -c icns "$ICONSET_TMP" -o "$ICNS_PATH" 2>/dev/null; then
        VOLICON_PATH="$ICNS_PATH"
    fi
fi

echo "==> Packaging $DMG_NAME"

if command -v create-dmg >/dev/null 2>&1 || { command -v brew >/dev/null 2>&1 && brew install create-dmg; }; then
    CREATE_DMG_ARGS=(
        --volname "$APP_NAME"
        --window-pos 200 120
        --window-size 660 400
        --icon-size 128
        --icon "${APP_NAME}.app" 165 190
        --hide-extension "${APP_NAME}.app"
        --app-drop-link 495 190
    )
    if [ -n "$VOLICON_PATH" ]; then
        CREATE_DMG_ARGS+=(--volicon "$VOLICON_PATH")
    fi

    create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_PATH" "$APP_PATH"
else
    echo "    create-dmg unavailable — falling back to hdiutil"

    STAGING_DIR="$(mktemp -d)/${APP_NAME}"
    mkdir -p "$STAGING_DIR"
    cp -R "$APP_PATH" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"

    TMP_DMG="$(mktemp -d)/${APP_NAME}-rw.dmg"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$TMP_DMG"

    MOUNT_DIR="/Volumes/$APP_NAME"
    hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_DIR"

    if [ -n "$VOLICON_PATH" ]; then
        cp "$VOLICON_PATH" "$MOUNT_DIR/.VolumeIcon.icns"
        SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
        SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
    fi

    osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set position of item "${APP_NAME}.app" of container window to {165, 190}
        set position of item "Applications" of container window to {495, 190}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

    hdiutil detach "$MOUNT_DIR"
    hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG_PATH"
    rm -rf "$(dirname "$STAGING_DIR")" "$(dirname "$TMP_DMG")"
fi

echo "==> Done: $DMG_PATH"
