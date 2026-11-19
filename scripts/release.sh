#!/usr/bin/env bash
# Builds a Developer ID signed + notarized sAlive zip, and optionally publishes it.
#
# Everything runs locally – no secrets are stored on GitHub:
#   - "Developer ID Application" certificate in the login keychain
#   - notarytool keychain profile (default: salive-notary), created once with
#       xcrun notarytool store-credentials salive-notary --key AuthKey_XXXX.p8 \
#         --key-id XXXX --issuer <issuer-id>
#   - `gh` logged in (only for --publish)
#
# Usage:
#   scripts/release.sh             build + notarize -> dist/sAlive-<version>.zip
#   scripts/release.sh --publish   ...then tag, create the GitHub release and
#                                  update the Homebrew tap
set -euo pipefail

PUBLISH=false
[[ "${1:-}" == "--publish" ]] && PUBLISH=true

cd "$(dirname "$0")/.."
ROOT="$PWD"
# Build outside the repo: iCloud-synced folders add xattrs that break codesign.
WORK="${WORK_DIR:-$HOME/Library/Developer/sAlive-release}"
DIST="$ROOT/dist"
NOTARY_PROFILE="${NOTARY_PROFILE:-salive-notary}"
REPO="fcemtopall/sAlive"
TAP_REPO="fcemtopall/homebrew-tap"
TEAM_ID="$(awk '/DEVELOPMENT_TEAM:/ {print $2; exit}' project.yml)"
VERSION="$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' project.yml)"
TAG="v$VERSION"
ZIP="$DIST/sAlive-$VERSION.zip"

if $PUBLISH; then
  [[ -z "$(git status --porcelain)" ]] || { echo "Working tree is not clean."; exit 1; }
  if git rev-parse "$TAG" >/dev/null 2>&1 || gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
    echo "$TAG already exists – bump MARKETING_VERSION in project.yml."; exit 1
  fi
fi

echo "==> sAlive $VERSION (team $TEAM_ID)"
rm -rf "$WORK" && mkdir -p "$WORK" "$DIST"

xcodegen generate --quiet

echo "==> Archiving"
xcodebuild archive \
  -scheme sAlive -configuration Release \
  -archivePath "$WORK/sAlive.xcarchive" \
  -derivedDataPath "$WORK/DerivedData" \
  -allowProvisioningUpdates \
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
  -allowProvisioningUpdates \
  -quiet
APP="$WORK/export/sAlive.app"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Notarizing (profile: $NOTARY_PROFILE)"
ditto -c -k --keepParent "$APP" "$WORK/notarize.zip"
xcrun notarytool submit "$WORK/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait \
  | tee "$WORK/notarize.log"
if ! grep -q "status: Accepted" "$WORK/notarize.log"; then
  ID="$(awk '/^  id:/ {print $2; exit}' "$WORK/notarize.log")"
  echo "Notarization failed. Details:"
  [[ -n "$ID" ]] && xcrun notarytool log "$ID" --keychain-profile "$NOTARY_PROFILE"
  exit 1
fi
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=2 "$APP"

echo "==> Packaging"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "$SHA" > "$ZIP.sha256"
echo "Built: $ZIP"
echo "sha256: $SHA"

$PUBLISH || exit 0

echo "==> Tagging $TAG and publishing GitHub release"
git tag -a "$TAG" -m "sAlive $VERSION"
git push origin "$TAG"
gh release create "$TAG" "$ZIP" -R "$REPO" --title "sAlive $VERSION" --generate-notes --verify-tag

echo "==> Updating Homebrew tap"
TAP_DIR="$WORK/homebrew-tap"
gh repo clone "$TAP_REPO" "$TAP_DIR" -- --quiet
mkdir -p "$TAP_DIR/Casks"
sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA/" packaging/salive.rb > "$TAP_DIR/Casks/salive.rb"
git -C "$TAP_DIR" add Casks/salive.rb
git -C "$TAP_DIR" commit -m "salive $VERSION"
git -C "$TAP_DIR" push --quiet

echo
echo "Published $TAG – users can now run: brew install --cask fcemtopall/tap/salive"
