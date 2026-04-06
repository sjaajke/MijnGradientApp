#!/bin/bash
# Build flir_extract tool using FLIR Atlas C SDK
set -euo pipefail

SDK_DIR="/Users/sjaaj/FLIR SDK Atlas-c-sdk-macosx-xcode15-arm64-2.18.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/flir_extract"

clang -O2 -arch arm64 \
  -I"$SDK_DIR/include" \
  -L"$SDK_DIR/lib" \
  -latlas_c_sdk \
  -Wl,-rpath,"$SDK_DIR/lib" \
  -o "$OUT" \
  "$SCRIPT_DIR/flir_extract.c"

echo "Built: $OUT"
