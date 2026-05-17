#!/usr/bin/env bash
set -euo pipefail

# Generates the macOS AppIcon image set from a 1024x1024 master PNG.
# Usage: scripts/make-appicon.sh [path-to-master.png]
#   default master: <repo>/icon.png

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

MASTER="${1:-$PROJECT_DIR/icon.png}"
APPICON_DIR="$PROJECT_DIR/Clip2GIF/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$MASTER" ]; then
  echo "Master image not found: $MASTER" >&2
  exit 1
fi

read -r W H < <(sips -g pixelWidth -g pixelHeight "$MASTER" | awk '/pixel/{print $2}' | xargs)
if [ "$W" != "1024" ] || [ "$H" != "1024" ]; then
  echo "WARNING: master is ${W}x${H}, expected 1024x1024 (continuing anyway)" >&2
fi

mkdir -p "$APPICON_DIR"

for SIZE in 16 32 64 128 256 512 1024; do
  sips -s format png -z "$SIZE" "$SIZE" "$MASTER" \
    --out "$APPICON_DIR/icon_${SIZE}.png" >/dev/null
  echo "    icon_${SIZE}.png"
done

echo "Generated AppIcon image set in $APPICON_DIR"
