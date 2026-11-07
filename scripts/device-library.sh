#!/bin/bash
# Lists the sticker library in the App Group container on the connected
# iPhone, or pulls it to a local folder. Extension diagnostics live here too:
# devicectl cannot attach to a Messages extension, so anything it needs to
# tell us is written into this container.
#   scripts/device-library.sh              # list
#   scripts/device-library.sh pull [dir]   # copy everything to dir (default ./.build/library)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
UDID="$(require_device)"
case "${1:-list}" in
  list)
    xcrun devicectl device info files --device "$UDID" \
      --domain-type appGroupDataContainer --domain-identifier "$APP_GROUP" ;;
  pull)
    DEST="${2:-$(dirname "$0")/../.build/library}"
    mkdir -p "$DEST"
    xcrun devicectl device copy from --device "$UDID" \
      --domain-type appGroupDataContainer --domain-identifier "$APP_GROUP" \
      --source . --destination "$DEST"
    echo "Pulled to $DEST" ;;
  *) echo "usage: device-library.sh [list|pull [dir]]" >&2; exit 2 ;;
esac
