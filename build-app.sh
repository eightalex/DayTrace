#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

swift build -c release --build-system native

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/daytrace-build.XXXXXX")"
APP_DIR="$STAGING_DIR/DayTrace.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INSTALL_DIR="/Applications/DayTrace.app"
LEGACY_APP_DIR="$SCRIPT_DIR/dist/DayTrace.app"
LEGACY_ZIP="$SCRIPT_DIR/DayTrace-macOS.zip"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/release/DayTrace" "$MACOS_DIR/DayTrace"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"

pkill -x DayTrace 2>/dev/null || true
if [ -e "$INSTALL_DIR" ]; then
    mv "$INSTALL_DIR" "$STAGING_DIR/DayTrace.previous.app"
fi
mv "$APP_DIR" "$INSTALL_DIR"
rm -rf "$STAGING_DIR"

# Old releases were kept inside the source tree. Keep the installed bundle unique.
rm -rf "$LEGACY_APP_DIR"
rmdir "$SCRIPT_DIR/dist" 2>/dev/null || true
rm -f "$LEGACY_ZIP"

echo "Installed: $INSTALL_DIR"
echo "Run:       open '$INSTALL_DIR'"
