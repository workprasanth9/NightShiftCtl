#!/bin/bash
# Builds dist/NightShiftCtl-<version>.pkg for Jamf or other MDM deployment.
# Installs NightShiftCtl.app to /Applications and the nightshift CLI to
# /usr/local/bin. Usage: ./Scripts/build-app-pkg.sh [--universal]
# Set PKG_SIGN_ID to a Developer ID Installer identity to sign the package.
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/build-app.sh "$@"
VERSION=$(sed -nE 's/.*current = "(.*)".*/\1/p' Sources/NightShiftKit/Version.swift)
IDENTIFIER="com.workprasanth9.NightShiftCtl"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"
mkdir -p "$ROOT/Applications" "$ROOT/usr/local/bin"
ditto dist/NightShiftCtl.app "$ROOT/Applications/NightShiftCtl.app"
install -m 755 dist/NightShiftCtl.app/Contents/Resources/nightshift "$ROOT/usr/local/bin/nightshift"
xattr -cr "$ROOT" 2>/dev/null || true
export COPYFILE_DISABLE=1

# Install to /Applications even if another copy of the app exists elsewhere.
pkgbuild --analyze --root "$ROOT" "$WORK/components.plist" >/dev/null
plutil -replace 0.BundleIsRelocatable -bool false "$WORK/components.plist"

PKG="dist/NightShiftCtl-${VERSION}.pkg"
SIGN_ARGS=()
if [[ -n "${PKG_SIGN_ID:-}" ]]; then SIGN_ARGS=(--sign "$PKG_SIGN_ID"); fi
pkgbuild --root "$ROOT" \
  --component-plist "$WORK/components.plist" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location / \
  --filter '/\._' --filter '\.DS_Store$' \
  ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} \
  "$PKG"

echo "Built $PKG"
pkgutil --payload-files "$PKG" | grep -E 'NightShiftCtl.app$|nightshift$'
