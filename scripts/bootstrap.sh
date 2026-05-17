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

echo "==> Running xcodegen..."
cd "$PROJECT_DIR"
xcodegen generate

echo ""
echo "Done! Open the project with:"
echo "  open Clip2GIF.xcodeproj"
