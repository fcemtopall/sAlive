#!/usr/bin/env bash
# Builds a Debug copy with your Apple Development certificate and installs it
# to /Applications (SMAppService daemons should run from /Applications).
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/sAlive-local"

xcodegen generate --quiet
xcodebuild -scheme sAlive -configuration Debug -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates -quiet build

osascript -e 'quit app id "io.github.fcemtopall.salive"' 2>/dev/null || true
rm -rf /Applications/sAlive.app
ditto "$DERIVED/Build/Products/Debug/sAlive.app" /Applications/sAlive.app
open /Applications/sAlive.app
echo "Installed /Applications/sAlive.app"
