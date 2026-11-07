#!/bin/bash
# Shared by the device-* scripts. Sourced, not executed.

# UDID of the first paired physical device, or $DEVICE if set.
device_udid() {
  if [[ -n "${DEVICE:-}" ]]; then echo "$DEVICE"; return; fi
  xcrun devicectl list devices --json-output - 2>/dev/null | python3 -c '
import json, sys
for d in json.load(sys.stdin)["result"]["devices"]:
    hw = d.get("hardwareProperties", {})
    if hw.get("reality") == "physical":
        print(hw["udid"]); break
'
}

require_device() {
  local udid; udid="$(device_udid)"
  if [[ -z "$udid" ]]; then
    echo "No paired physical device found. Set DEVICE=<udid> or pair one." >&2
    exit 1
  fi
  echo "$udid"
}

APP_GROUP="group.com.blacktree.stickerclip"
APP_BUNDLE_ID="com.blacktree.stickerclip"
