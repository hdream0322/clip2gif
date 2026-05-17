#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Checking dependencies..."

if ! command -v xcodegen &>/dev/null; then
  echo "xcodegen not found. Install it with:"
  echo "  brew install xcodegen"
  exit 1
fi

if ! command -v gifski &>/dev/null; then
  echo "gifski not found. Install it with:"
  echo "  brew install gifski"
  exit 1
fi

echo "==> Copying gifski binary..."
GIFSKI_SRC="$(brew --prefix)/bin/gifski"
GIFSKI_DST="$PROJECT_DIR/Clip2GIF/Resources/bin/gifski"
cp "$GIFSKI_SRC" "$GIFSKI_DST"
chmod +x "$GIFSKI_DST"
echo "    Copied gifski to Clip2GIF/Resources/bin/gifski"

# gifski is AGPL-3.0-only. When the binary is redistributed, its license
# text must travel with it. Copy the LICENSE from the installed Cellar so
# it always matches the bundled binary's exact version.
GIFSKI_VER="$(gifski --version | awk '{print $2}')"
GIFSKI_LICENSE_SRC="$(brew --cellar gifski)/$GIFSKI_VER/LICENSE"
GIFSKI_LICENSE_DST="$PROJECT_DIR/Clip2GIF/Resources/bin/gifski-LICENSE.txt"
if [ -f "$GIFSKI_LICENSE_SRC" ]; then
  cp "$GIFSKI_LICENSE_SRC" "$GIFSKI_LICENSE_DST"
  echo "    Copied gifski LICENSE (v$GIFSKI_VER) -> gifski-LICENSE.txt"
  echo "    NOTE: if v$GIFSKI_VER differs from THIRD_PARTY_NOTICES.md,"
  echo "          update the version and Corresponding Source links there."
else
  echo "    WARNING: gifski LICENSE not found at $GIFSKI_LICENSE_SRC"
  echo "             AGPL-3.0 requires shipping the license with the binary."
fi

echo "==> Running xcodegen..."
cd "$PROJECT_DIR"
xcodegen generate

echo ""
echo "Done! Open the project with:"
echo "  open Clip2GIF.xcodeproj"
