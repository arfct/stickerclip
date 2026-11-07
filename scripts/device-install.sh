#!/bin/bash
# Builds the app for the connected iPhone and installs it.
#   scripts/device-install.sh            # first paired device
#   DEVICE=<udid> scripts/device-install.sh
#   MESSAGES_EXTENSION_SUFFIX=messages scripts/device-install.sh   # while the real ID is unavailable
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh
UDID="$(require_device)"
DERIVED="${DERIVED_DATA:-.build/DerivedData}"

xcodebuild -project Stickerclip.xcodeproj -scheme Stickerclip \
  -destination "platform=iOS,id=$UDID" -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates ${MESSAGES_EXTENSION_SUFFIX:+MESSAGES_EXTENSION_SUFFIX=$MESSAGES_EXTENSION_SUFFIX} build 2>&1 | grep -E "error:|warning: .*\.swift|BUILD (SUCCEEDED|FAILED)"

APP="$DERIVED/Build/Products/Debug-iphoneos/Stickerclip.app"
xcrun devicectl device install app --device "$UDID" "$APP" | grep -E "installed|bundleID|error"
for plist in "$APP/Info.plist" "$APP"/PlugIns/*.appex/Info.plist; do
  printf '  %s\n' "$(plutil -extract CFBundleIdentifier raw "$plist")"
done
