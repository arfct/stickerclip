#!/bin/bash
# Regenerates Stickerclip.xcodeproj from project.yml. Run after any change to
# the spec; the .xcodeproj is git-ignored.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
