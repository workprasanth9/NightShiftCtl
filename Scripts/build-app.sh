#!/bin/bash
# Builds dist/NightShiftCtl.app (menu bar app) with the nightshift CLI inside it.
# Usage: ./Scripts/build-app.sh [--universal]
# Command Line Tools build for the host architecture. --universal needs Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -nE 's/.*current = "(.*)".*/\1/p' Sources/NightShiftKit/Version.swift)
ARCH_ARGS=()
if [[ "${1:-}" == "--universal" ]]; then
  ARCH_ARGS=(--arch arm64 --arch x86_64)
fi

swift build -c release ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"} --product NightShiftCtlApp
swift build -c release ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"} --product nightshift
BIN_DIR=$(swift build -c release ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"} --show-bin-path)

APP="dist/NightShiftCtl.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NightShiftCtlApp" "$APP/Contents/MacOS/NightShiftCtl"
cp "$BIN_DIR/nightshift" "$APP/Contents/Resources/nightshift"
cp App/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed "s/__VERSION__/${VERSION}/g" App/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# Ad hoc signature so macOS treats it as a proper bundle. Replace "-" with a
# Developer ID identity to sign for distribution.
SIGN_ID="${SIGN_ID:--}"
codesign --force --options runtime --timestamp=none --sign "$SIGN_ID" "$APP/Contents/Resources/nightshift"
codesign --force --options runtime --timestamp=none --entitlements App/NightShiftCtl.entitlements --sign "$SIGN_ID" "$APP"
codesign --verify --strict "$APP"
ENTITLEMENTS=$(codesign -d --entitlements - "$APP" 2>/dev/null || true)
if [[ "$ENTITLEMENTS" != *"automation.apple-events"* ]]; then
  echo "error: apple-events entitlement missing from the signed app" >&2
  exit 1
fi

echo "Built $APP ($VERSION, $(lipo -archs "$APP/Contents/MacOS/NightShiftCtl"))"
