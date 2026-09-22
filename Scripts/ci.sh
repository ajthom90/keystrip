#!/bin/bash
# The exact checks CI runs. Run locally before pushing.
set -euo pipefail
cd "$(dirname "$0")/.."
swift test --package-path KeystripCore
xcodegen generate
for destination in "platform=macOS" "generic/platform=iOS Simulator"; do
  xcodebuild -project Keystrip.xcodeproj -scheme Keystrip -destination "$destination" \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build
done
echo "CI checks passed"
