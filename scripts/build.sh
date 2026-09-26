#!/usr/bin/env bash
#
# Generates the Xcode project (via XcodeGen) and builds a Release, arm64
# Lidless.app. Run this on macOS with Xcode (or the Xcode Command Line
# Tools) installed.
#
# Usage:
#   scripts/build.sh
#
# Output:
#   build/Build/Products/Release/Lidless.app

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="$ROOT_DIR/build"
SCHEME="Lidless"
PROJECT="Lidless.xcodeproj"

echo "==> Checking for XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo "    xcodegen not found — installing via Homebrew"
        brew install xcodegen
    else
        echo "error: xcodegen is required but not installed, and Homebrew is not available." >&2
        echo "       Install it manually: https://github.com/yonaskolb/XcodeGen" >&2
        exit 1
    fi
fi

echo "==> Generating $PROJECT from project.yml"
xcodegen generate

echo "==> Building $SCHEME (Release, arm64)"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS=arm64 \
    clean build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/Lidless.app"

if [ ! -d "$APP_PATH" ]; then
    echo "error: build did not produce $APP_PATH" >&2
    exit 1
fi

echo "==> Built: $APP_PATH"
