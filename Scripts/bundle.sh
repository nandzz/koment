#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Koment.app"
DERIVED="$ROOT/.build/xcode"
BUILT="$DERIVED/Build/Products/Release/Koment.app"

cd "$ROOT"
xcodebuild \
    -project Koment.xcodeproj \
    -scheme Koment \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    -skipPackagePluginValidation \
    build

rm -rf "$APP"
mkdir -p "$ROOT/build"
cp -R "$BUILT" "$APP"

codesign --verify --strict "$APP"
codesign -d --verbose=2 "$APP" 2>&1 | grep -E "^(Identifier|TeamIdentifier|Authority)" | head -3 || true

echo "built $APP"
echo "run it with: open '$APP'"
