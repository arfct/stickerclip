#!/bin/bash
# Captures the connected iPhone's screen.
#   scripts/device-screenshot.sh [out.png]
set -euo pipefail
source "$(dirname "$0")/lib.sh"
UDID="$(require_device)"
OUT="${1:-$(dirname "$0")/../.build/screenshot-$(date +%H%M%S).png}"
mkdir -p "$(dirname "$OUT")"
xcrun devicectl device capture screenshot --device "$UDID" --destination "$OUT" | tail -1
echo "$OUT"
