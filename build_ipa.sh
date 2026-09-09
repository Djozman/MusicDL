#!/usr/bin/env bash
#
# build_ipa.sh — build the iOS MusicDL app and assemble a sideloadable .ipa.
#
# Produces dist/iOSMusicDL.ipa (unsigned) so you can sideload with Sideloadly,
# AltStore, or re-sign with your own Apple Development certificate.
#
# To re-sign with your own certificate + provisioning profile, set:
#   BUILD_CERT="Apple Development: name (TEAMID)"  PROVISION="dist/Dev.mobileprovision"
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$ROOT/iOSMusicDL"
PROJ="$IOS_DIR/iOSMusicDL.xcodeproj"
CONFIGURATION=Release
OUT_DIR="$ROOT/dist"
IPHONEOS_DEPLOYMENT_TARGET=16.0

echo "▸ Generating Xcode project (xcodegen)…"
( cd "$IOS_DIR" && xcodegen generate --spec project.yml )

# Build for physical device (iphoneos), no code signing.
echo "▸ Building ($CONFIGURATION)…"
xcodebuild \
  -project "$PROJ" \
  -scheme iOSMusicDL \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$IOS_DIR/build/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  build

APP_PATH="$IOS_DIR/build/DerivedData/Build/Products/${CONFIGURATION}-iphoneos/iOSMusicDL.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "✗ App bundle not found at $APP_PATH" >&2
  exit 1
fi

echo "▸ Assembling .ipa…"
mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR/Payload" "$OUT_DIR/iOSMusicDL.ipa"
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP_PATH" "$OUT_DIR/Payload/iOSMusicDL.app"

# Re-sign from a signing identity if provided; otherwise leave codesign-less.
if [[ -n "${BUILD_CERT:-}" ]]; then
  echo "▸ Re-signing with $BUILD_CERT…"
  if [[ -n "${PROVISION:-}" && -f "$PROVISION" ]]; then
    cp "$PROVISION" "$OUT_DIR/Payload/iOSMusicDL.app/embedded.mobileprovision"
    /usr/bin/codesign -f -s "$BUILD_CERT" --timestamp=none \
      "$OUT_DIR/Payload/iOSMusicDL.app"
  else
    echo "⚠ PROVISION not set — building unsigned (sideload tools can still install)." >&2
  fi
else
  echo "▸ Not signed (BUILD_CERT unset). Sideload via Sideloadly/AltStore."
fi

( cd "$OUT_DIR" && zip -qr iOSMusicDL.ipa Payload )
rm -rf "$OUT_DIR/Payload"

echo "✓ Built: $OUT_DIR/iOSMusicDL.ipa"