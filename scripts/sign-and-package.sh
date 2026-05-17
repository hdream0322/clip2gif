#!/usr/bin/env bash
set -euo pipefail

# Ad-hoc signs a built Clip2GIF.app (inside-out: nested gifski first, then the
# app bundle) and packages it into a distributable DMG.
#
# Ad-hoc (`codesign -s -`) is intentional: it costs nothing, lets the app run
# on Apple Silicon (unsigned arm64 is killed by the kernel), and keeps a stable
# code identity. It is NOT notarized, so first launch still shows a Gatekeeper
# prompt — see README for the "open anyway" instructions.
#
# Usage: scripts/sign-and-package.sh <path-to-Clip2GIF.app> <version>
#   e.g. scripts/sign-and-package.sh build/Build/Products/Release/Clip2GIF.app 0.1.0

APP_PATH="${1:?usage: sign-and-package.sh <path-to.app> <version>}"
VERSION="${2:?usage: sign-and-package.sh <path-to.app> <version>}"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: app bundle not found: $APP_PATH" >&2
  exit 1
fi

# Normalize to an absolute path.
APP_PATH="$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")"
APP_NAME="$(basename "$APP_PATH")"            # Clip2GIF.app
GIFSKI="$APP_PATH/Contents/Resources/gifski"

OUT_DIR="$(pwd)/dist"
mkdir -p "$OUT_DIR"
DMG_PATH="$OUT_DIR/Clip2GIF-${VERSION}.dmg"

echo "==> Ad-hoc signing (inside-out)"
if [ ! -f "$GIFSKI" ]; then
  echo "ERROR: bundled gifski not found at $GIFSKI" >&2
  echo "       (the 'Copy gifski binary' postBuildScript must run before this)" >&2
  exit 1
fi

sign() { codesign --force --sign - "$@"; }

# Sparkle.framework ships its own nested code (XPC services + helper apps).
# Re-signing the outer app breaks the framework's seal unless every nested
# Mach-O is re-signed first, inside-out. Without this the updater's XPC
# services fail to launch and "Check for Updates" silently does nothing.
SPARKLE_FW="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
  echo "==> Signing Sparkle.framework nested code"
  SPK_V="$SPARKLE_FW/Versions/B"
  for xpc in "$SPK_V/XPCServices/"*.xpc; do
    [ -e "$xpc" ] && sign "$xpc"
  done
  [ -e "$SPK_V/Autoupdate" ]   && sign "$SPK_V/Autoupdate"
  [ -e "$SPK_V/Updater.app" ]  && sign "$SPK_V/Updater.app"
  sign "$SPARKLE_FW"
fi

chmod +x "$GIFSKI"
sign "$GIFSKI"
sign "$APP_PATH"

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP_PATH"
codesign --verify --verbose=2 "$GIFSKI"
[ -d "$SPARKLE_FW" ] && codesign --verify --verbose=2 "$SPARKLE_FW"

echo "==> Building DMG: $DMG_PATH"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_PATH" "$STAGING/"
rm -f "$DMG_PATH"

# Preferred: Homebrew `create-dmg` (drag-to-Applications layout). Its AppleScript
# styling can fail on headless CI; `|| true` + the existence check below make
# that non-fatal, and we fall back to a plain hdiutil DMG when needed.
if command -v create-dmg >/dev/null 2>&1; then
  create-dmg \
    --volname "Clip2GIF" \
    --window-size 540 380 \
    --icon-size 100 \
    --icon "$APP_NAME" 140 190 \
    --app-drop-link 400 190 \
    --no-internet-enable \
    "$DMG_PATH" "$STAGING" || true
fi

if [ ! -f "$DMG_PATH" ]; then
  echo "==> create-dmg unavailable or failed; falling back to hdiutil"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create -volname "Clip2GIF" -srcfolder "$STAGING" \
    -ov -format UDZO "$DMG_PATH"
fi

echo "==> Done: $DMG_PATH"
ls -la "$DMG_PATH"
