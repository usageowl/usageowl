#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="UsageOwl"
BUNDLE_ID="com.usageowl.app"
BIN_NAME="UsageOwl"

# Single source of truth for the shipped version. The updater compares this
# (via CFBundleShortVersionString) against the latest GitHub release tag, so a
# release MUST be tagged v$VERSION or every user is told they're out of date.
VERSION="${VERSION:-1.0.0}"

# Universal, not arm64-only. The README and the site FAQ both promise a binary
# that "runs natively on Apple Silicon and Intel"; building one arch made that
# false and left the app unable to launch at all on Intel Macs.
swift build -c release --arch arm64 --arch x86_64

# Multi-arch builds land in a different place than single-arch ones.
BUILT_BIN=".build/apple/Products/Release/${BIN_NAME}"
if [ ! -f "$BUILT_BIN" ]; then
    BUILT_BIN=".build/arm64-apple-macosx/release/${BIN_NAME}"
fi
[ -f "$BUILT_BIN" ] || { echo "error: no built binary found" >&2; exit 1; }

# Stage in a non-iCloud temp dir: the Desktop is FileProvider-synced, and its
# fpfs/FinderInfo xattrs make Developer ID signing fail with "detritus".
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT
STAGING_APP="$STAGING_DIR/${APP_NAME}.app"

mkdir -p "$STAGING_APP/Contents/MacOS"
mkdir -p "$STAGING_APP/Contents/Resources"

cp "$BUILT_BIN" "$STAGING_APP/Contents/MacOS/${APP_NAME}"
cp "Resources/AppIcon.icns" "$STAGING_APP/Contents/Resources/AppIcon.icns"
cp -R "BrowserBridge/usageowl-bridge" "$STAGING_APP/Contents/Resources/usageowl-bridge"

cat > "$STAGING_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
PLIST

# Sign with a stable Developer ID when available: ad-hoc signatures change on
# every build, which invalidates Keychain ACLs and re-triggers access prompts.
# (The team ID intentionally lives only in this script.)
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"([^"]+)".*/\1/' || true)

if [ -n "$SIGNING_IDENTITY" ]; then
    codesign --force --deep --sign "$SIGNING_IDENTITY" --options runtime "$STAGING_APP"
    echo "Signed with Developer ID: ${SIGNING_IDENTITY} (hardened runtime)"
else
    codesign --force --deep --sign - "$STAGING_APP"
    echo "Signed ad-hoc (no Developer ID identity found)"
fi

APP_DIR="dist/${APP_NAME}.app"
rm -rf "$APP_DIR"
mkdir -p dist
mv "$STAGING_APP" "$APP_DIR"

# Moving into dist/ re-attaches com.apple.FinderInfo, because the Desktop is
# FileProvider-synced. That xattr doesn't invalidate the seal, but it does make
# `codesign --verify --strict` (and therefore notarization) reject the bundle
# as "detritus". Strip it after the move, then prove the signature still holds.
xattr -cr "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built: $APP_DIR (version ${VERSION})"
echo -n "Architectures: "
lipo -archs "$APP_DIR/Contents/MacOS/${APP_NAME}"
echo "Signature: verified"
