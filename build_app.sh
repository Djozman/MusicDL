#!/usr/bin/env bash
#
# build_app.sh — build the SwiftMusicDL frontend and assemble a self-contained
# SwiftMusicDL.app bundle in one step.
#
# The bundle produced here is treated as fully generated output: rebuilding
# from scratch reconstructs Contents/, Info.plist, the binary, resources
# (including AppIcon.icns) and re-signs. Do not hand-edit the bundle.
#
set -euo pipefail

# Project layout
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/SwiftMusicDL"
APP="$ROOT/SwiftMusicDL.app"
BUNDLED_PY="/Library/Frameworks/Python.framework/Versions/3.14/bin/python3"
REPO_PATH="$ROOT"

BUILD_CONFIG="${BUILD_CONFIG:-debug}"
BUNDLE_ID="${BUNDLE_ID:-com.local.SwiftMusicDL}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_MACOS="${MIN_MACOS:-13.0}"

# ── Resolve the built binary ────────────────────────────────────────────────
echo "▸ swift build ($BUILD_CONFIG)…"
swift build -c "$BUILD_CONFIG"

SUBDIR="apple"
case "$BUILD_CONFIG" in
    release) SUBDIR="release" ;;
    debug)   SUBDIR="debug" ;;
esac
BIN="$(find "$ROOT/.build/$SUBDIR" -maxdepth 1 -type f -name 'SwiftMusicDL' | head -n1)"
if [[ -z "$BIN" ]]; then
    BIN="$(find "$ROOT/.build" -maxdepth 3 -type f -name 'SwiftMusicDL' | grep -v dSYM | head -n1)"
fi
if [[ -z "$BIN" ]]; then
    echo "✗ Could not locate the SwiftMusicDL binary after build." >&2
    exit 1
fi

# ── Assemble the .app bundle from scratch ──────────────────────────────────
echo "▸ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/SwiftMusicDL"
chmod +x "$APP/Contents/MacOS/SwiftMusicDL"

# Info.plist is generated fresh so the bundle is reproducible.
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>SwiftMusicDL</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>SwiftMusicDL</string>
	<key>CFBundleDisplayName</key>
	<string>SwiftMusicDL</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$MARKETING_VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>LSMinimumSystemVersion</key>
	<string>$MIN_MACOS</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.music</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

# Icon — must be present in Resources or Finder shows a blank glyph.
if [[ -f "$SRC/Resources/AppIcon.icns" ]]; then
    cp "$SRC/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
    echo "⚠ AppIcon.icns not found at $SRC/Resources/AppIcon.icns — bundle will have no icon." >&2
fi

# ── Sign (ad-hoc) ───────────────────────────────────────────────────────────
echo "▸ Code-signing (ad-hoc)..."
codesign --force --deep --sign - "$APP"

echo "✓ Built: $APP"
echo "  py:      $BUNDLED_PY (edit BackendService.swift if this differs)"
echo "  repo:    $REPO_PATH (edit BackendService.swift if this differs)"