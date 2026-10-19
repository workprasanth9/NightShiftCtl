#!/bin/bash
# Builds a release binary for the host architecture and zips it into dist/.
# With Xcode installed you can pass --universal to build arm64 and x86_64.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -nE 's/.*current = "(.*)".*/\1/p' Sources/NightShiftKit/Version.swift)
mkdir -p dist

if [[ "${1:-}" == "--universal" ]]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
  SUFFIX="universal"
else
  swift build -c release
  BIN_DIR=$(swift build -c release --show-bin-path)
  SUFFIX=$(uname -m)
fi

cp "$BIN_DIR/nightshift" dist/nightshift
( cd dist && zip -q "nightshift-${VERSION}-macos-${SUFFIX}.zip" nightshift )
echo "Built dist/nightshift-${VERSION}-macos-${SUFFIX}.zip"
