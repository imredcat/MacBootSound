#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MacBootSound"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

cd "$ROOT_DIR"

echo "Building universal release binaries (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64

BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Helpers"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [ ! -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    swift "$ROOT_DIR/scripts/generate_icon.swift"
fi
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$BIN_DIR/MacBootSound" "$APP_BUNDLE/Contents/MacOS/MacBootSound"
cp "$BIN_DIR/MacBootSoundPlayer" "$APP_BUNDLE/Contents/Helpers/MacBootSoundPlayer"

chmod 755 "$APP_BUNDLE/Contents/MacOS/MacBootSound"
chmod 755 "$APP_BUNDLE/Contents/Helpers/MacBootSoundPlayer"

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
