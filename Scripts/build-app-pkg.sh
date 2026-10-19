#!/bin/bash
# Builds dist/NightShiftCtl-<version>.pkg for Jamf or other MDM deployment.
# Installs NightShiftCtl.app to /Applications and the nightshift CLI to
# /usr/local/bin. Usage: ./Scripts/build-app-pkg.sh [--universal]
# The result is a product archive (distribution package) with a thank you page.
# Set PKG_SIGN_ID to a Developer ID Installer identity to sign the package.
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/build-app.sh "$@"
VERSION=$(sed -nE 's/.*current = "(.*)".*/\1/p' Sources/NightShiftKit/Version.swift)
IDENTIFIER="com.workprasanth9.NightShiftCtl"
REPO_URL=$(sed -nE 's/.*repositoryURL = "(.*)".*/\1/p' Sources/NightShiftKit/Version.swift)

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
COMPONENT="$WORK/packages/NightShiftCtl-component.pkg"
mkdir -p "$WORK/packages" "$WORK/resources"
pkgbuild --root "$ROOT" \
  --component-plist "$WORK/components.plist" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location / \
  --filter '\.DS_Store$' \
  "$COMPONENT"

# Thank you page, with the version and project link filled in from Version.swift.
sed -e "s|__VERSION__|${VERSION}|g" -e "s|__REPO_URL__|${REPO_URL}|g" \
  Installer/conclusion.html > "$WORK/resources/conclusion.html"

productbuild --synthesize --package "$COMPONENT" "$WORK/distribution.xml" >/dev/null
python3 - "$WORK/distribution.xml" "$VERSION" <<'PY'
import re, sys
path, version = sys.argv[1], sys.argv[2]
xml = open(path).read()
xml = re.sub(r'\s*<options [^>]*/>', '', xml)
extra = (
    f'\n    <title>NightShiftCtl {version}</title>'
    '\n    <conclusion file="conclusion.html" mime-type="text/html"/>'
    '\n    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>'
    '\n    <domains enable_localSystem="true"/>'
)
xml = re.sub(r'(<installer-gui-script[^>]*>)', lambda m: m.group(1) + extra, xml, count=1)
open(path, 'w').write(xml)
PY

SIGN_ARGS=()
if [[ -n "${PKG_SIGN_ID:-}" ]]; then SIGN_ARGS=(--sign "$PKG_SIGN_ID"); fi
productbuild --distribution "$WORK/distribution.xml" \
  --resources "$WORK/resources" \
  --package-path "$WORK/packages" \
  ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} \
  "$PKG"

cp "$WORK/distribution.xml" dist/distribution.xml
echo "Built $PKG"
pkgutil --payload-files "$PKG" 2>/dev/null | grep -E 'NightShiftCtl.app$|nightshift$' || true
