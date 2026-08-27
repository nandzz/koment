#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$HOME/.claude/commands"

mkdir -p "$TARGET"
rm -f "$TARGET/koment.md"
cp "$ROOT/Resources/koment.md" "$TARGET/koment.md"

echo "installed $TARGET/koment.md"
echo "use /koment in any repository"
