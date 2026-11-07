#!/bin/bash
# Puts an image on the connected iPhone's clipboard, so a paste can be tested
# with known content. The UTI defaults to public.png.
#   scripts/device-pasteboard.sh path/to/image.png [public.jpeg]
set -euo pipefail
source "$(dirname "$0")/lib.sh"
UDID="$(require_device)"
FILE="${1:?usage: device-pasteboard.sh <image> [uti]}"
UTI="${2:-public.png}"
xcrun devicectl device pasteboard copy --device "$UDID" --type "$UTI" --file "$FILE"
xcrun devicectl device pasteboard info --device "$UDID"
