#!/usr/bin/env bash
# Builds a Developer ID signed + notarized sAlive.zip.
#
# Requirements:
#   - "Developer ID Application" certificate in the keychain
#   - Notarization credentials, either:
#       NOTARY_PROFILE=<name>   (created with `xcrun notarytool store-credentials`)
#     or App Store Connect API key:
#       NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER
#
# Usage: scripts/release.sh            -> dist/sAlive-<version>.zip
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
# Build outside the repo: iCloud-synced folders add xattrs that break codesign.
WORK="${WORK_DIR:-$HOME/Library/Developer/sAlive-release}"
DIST="$ROOT/dist"
TEAM_ID="$(awk '/DEVELOPMENT_TEAM:/ {print $2; exit}' project.yml)"
VERSION="$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' project.yml)"
ZIP="$DIST/sAlive-$VERSION.zip"

echo "==> sAlive $VERSION (team $TEAM_ID)"
rm -rf "$WORK" && mkdir -p "$WORK" "$DIST"

xcodegen generate --quiet

echo "==> Archiving"
xcodebuild archive \
  -scheme sAlive -configuration Release \
  -archivePath "$WORK/sAlive.xcarchive" \
  -derivedDataPath "$WORK/DerivedData" \
  -allowProvisioningUpdates ${XCODE_AUTH_ARGS:-} \
  -quiet

echo "==> Exporting with Developer ID"
cat > "$WORK/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
EOF
xcodebuild -exportArchive \
  -archivePath "$WORK/sAlive.xcarchive" \
  -exportPath "$WORK/export" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" \
  -allowProvisioningUpdates ${XCODE_AUTH_ARGS:-}
APP="$WORK/export/sAlive.app"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Notarizing"
ditto -c -k --keepParent "$APP" "$WORK/notarize.zip"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$WORK/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
else
  xcrun notarytool submit "$WORK/notarize.zip" \
    --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER" --wait
fi
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=2 "$APP"

echo "==> Packaging"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "$SHA" > "$ZIP.sha256"

echo
echo "Done: $ZIP"
echo "sha256: $SHA"
