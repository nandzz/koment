#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Koment.app"
DIST="$ROOT/dist"
PROFILE="${NOTARY_PROFILE:-koment-notary}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$DIST/Koment-$VERSION.dmg"

"$ROOT/Scripts/bundle.sh"

if ! codesign -dvv "$APP" 2>&1 | grep -q "^Authority=Developer ID Application"; then
    echo "the bundle is not signed with a Developer ID — write Signing.local.xcconfig first" >&2
    exit 1
fi

rm -rf "$DIST"
mkdir -p "$DIST"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/Koment.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Koment -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo
echo "$DMG"
shasum -a 256 "$DMG"
