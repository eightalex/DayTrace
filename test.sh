#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/.build/self-test"
mkdir -p "$BUILD_DIR"

swiftc \
  Sources/DayTrace/Models.swift \
  Tests/SelfTest.swift \
  -o "$BUILD_DIR/DayTraceSelfTest"

"$BUILD_DIR/DayTraceSelfTest"
