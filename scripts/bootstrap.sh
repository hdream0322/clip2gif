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

if ! command -v dylibbundler &>/dev/null; then
  echo "dylibbundler not found. Install it with:"
  echo "  brew install dylibbundler"
  exit 1
fi

# Homebrew's gifski is dynamically linked against Homebrew's ffmpeg dylibs
# by absolute, version-numbered path (e.g. /opt/homebrew/opt/ffmpeg/lib/
# libavutil.60.dylib). If the user later runs `brew upgrade ffmpeg` (which
# often happens as a side effect of upgrading macOS/Xcode/Homebrew itself),
# the old versioned .dylib is deleted and the previously-copied gifski
# instantly fails to launch: dyld aborts (SIGABRT) before main() even runs,
# surfacing to the user as "GIF 인코딩에 실패했습니다 (코드 6)". dylibbundler
# vendors gifski's full dependency tree into Resources/bin/lib and rewrites
# gifski's load commands to @executable_path/lib/..., making the bundled
# binary fully self-contained and immune to future Homebrew upgrades.
BIN_DIR="$PROJECT_DIR/Clip2GIF/Resources/bin"
LIB_DIR="$BIN_DIR/lib"
GIFSKI_DST="$BIN_DIR/gifski"

echo "==> Copying gifski binary..."
GIFSKI_SRC="$(brew --prefix)/bin/gifski"
cp "$GIFSKI_SRC" "$GIFSKI_DST"
chmod +x "$GIFSKI_DST"
echo "    Copied gifski to Clip2GIF/Resources/bin/gifski"

echo "==> Vendoring dynamic library dependencies..."
rm -rf "$LIB_DIR"
mkdir -p "$LIB_DIR"
dylibbundler -od -b -x "$GIFSKI_DST" -d "$LIB_DIR" -p '@executable_path/lib/'
echo "    Vendored $(ls "$LIB_DIR" | wc -l | tr -d ' ') dylib(s) into Clip2GIF/Resources/bin/lib"

GIFSKI_SHA256="$(shasum -a 256 "$GIFSKI_DST" | awk '{print $1}')"
SETTINGS_FILE="$PROJECT_DIR/Clip2GIF/Services/GifskiEncoder.swift"
sed -i '' -E "s/\"[0-9a-f]{64,}\"/\"$GIFSKI_SHA256\"/" "$SETTINGS_FILE"
echo "    Updated expectedSHA256 in GifskiEncoder.swift -> $GIFSKI_SHA256"

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
