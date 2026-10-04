#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 source.png output.icns" >&2
    exit 1
fi

SOURCE_PATH="$1"
OUTPUT_PATH="$2"
ICONSET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/daytrace-iconset.XXXXXX")/DayTrace.iconset"
trap 'rm -rf "${ICONSET_DIR:h}"' EXIT

mkdir -p "$ICONSET_DIR"

for specification in \
    "16 icon_16x16.png" \
    "32 icon_16x16@2x.png" \
    "32 icon_32x32.png" \
    "64 icon_32x32@2x.png" \
    "128 icon_128x128.png" \
    "256 icon_128x128@2x.png" \
    "256 icon_256x256.png" \
    "512 icon_256x256@2x.png" \
    "512 icon_512x512.png" \
    "1024 icon_512x512@2x.png"; do
    size="${specification%% *}"
    file_name="${specification#* }"
    sips -z "$size" "$size" "$SOURCE_PATH" --out "$ICONSET_DIR/$file_name" >/dev/null
done

iconutil --convert icns --output "$OUTPUT_PATH" "$ICONSET_DIR"
echo "Generated: $OUTPUT_PATH"
