#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Koment.app"
DIST="$ROOT/dist"
PROFILE="${NOTARY_PROFILE:-koment-notary}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$DIST/Koment-$VERSION.dmg"

"$ROOT/Scripts/bundle.sh"

SIGNATURE="$(codesign -dvv "$APP" 2>&1)"

if ! grep -q "^Authority=Developer ID Application" <<<"$SIGNATURE"; then
    echo "the bundle is not signed with a Developer ID — write Signing.local.xcconfig first" >&2
    exit 1
fi

if ! grep -q "^Timestamp=" <<<"$SIGNATURE"; then
    echo "the signature has no secure timestamp — Apple rejects it for notarization" >&2
    exit 1
fi

for BINARY in "$APP/Contents/MacOS/Koment" "$APP/Contents/Helpers/KomentMCP"; do
    ENTITLEMENTS="$(codesign -d --entitlements :- "$BINARY" 2>/dev/null || true)"
    if grep -q "get-task-allow" <<<"$ENTITLEMENTS"; then
        echo "$BINARY carries the debug entitlement get-task-allow — Apple rejects it" >&2
        exit 1
    fi
done

rm -rf "$DIST"
mkdir -p "$DIST"

# the app must be stapled before the DMG is built, or the copy a user drags out carries no ticket
ZIP="$DIST/Koment-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"

STAGE="$(mktemp -d)"
ditto "$APP" "$STAGE/Koment.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Koment -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo
echo "$DMG"
shasum -a 256 "$DMG"
