#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
ICON_DOCUMENT="$PROJECT_DIR/Resources/DayTrace.icon"
ICON_TOOL="/Applications/Icon Composer.app/Contents/Executables/ictool"
RENDER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/daytrace-liquid-glass.XXXXXX")"
trap 'rm -rf "$RENDER_DIR"' EXIT

if [[ ! -x "$ICON_TOOL" ]]; then
    echo "Icon Composer is required to generate the Liquid Glass app icon." >&2
    exit 1
fi

render_icon() {
    local rendition="$1"
    local png_path="$2"
    local icns_path="$3"
    local rendered_path="$RENDER_DIR/${rendition}.png"

    "$ICON_TOOL" "$ICON_DOCUMENT" \
        --export-image \
        --output-file "$rendered_path" \
        --platform macOS \
        --rendition "$rendition" \
        --width 512 \
        --height 512 \
        --scale 2

    "$SCRIPT_DIR/inset-app-icon.swift" "$rendered_path" "$png_path"
    "$SCRIPT_DIR/generate-icns.sh" "$png_path" "$icns_path"
}

render_icon \
    "Default" \
    "$PROJECT_DIR/Resources/AppIcon-1024.png" \
    "$PROJECT_DIR/Resources/DayTrace.icns"

render_icon \
    "Dark" \
    "$PROJECT_DIR/Resources/AppIconDark-1024.png" \
    "$PROJECT_DIR/Resources/DayTraceDark.icns"

echo "Generated Liquid Glass icons from: $ICON_DOCUMENT"
