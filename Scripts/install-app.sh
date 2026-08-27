#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Koment.app"

if [ ! -d "$APP" ]; then
    echo "no bundle at $APP — run Scripts/bundle.sh first" >&2
    exit 1
fi

if [ -w /Applications ]; then
    DESTINATION="/Applications"
else
    DESTINATION="$HOME/Applications"
    mkdir -p "$DESTINATION"
fi

osascript -e 'quit app "Koment"' 2>/dev/null || true
rm -rf "$DESTINATION/Koment.app"
cp -R "$APP" "$DESTINATION/Koment.app"
xattr -cr "$DESTINATION/Koment.app"

echo "installed $DESTINATION/Koment.app"
