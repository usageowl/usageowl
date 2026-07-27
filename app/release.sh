#!/bin/bash
#
# Builds, signs, notarizes and staples a release DMG.
#
#   ./release.sh 1.0.0
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate in the login Keychain.
#   2. Apple credentials for notarization, either:
#
#        export APPLE_ID="you@example.com"
#        export APPLE_PASSWORD="abcd-efgh-ijkl-mnop"   # app-specific password
#        export APPLE_TEAM_ID="2CL3959UYK"
#
#      ...or a stored Keychain profile:
#
#        xcrun notarytool store-credentials "notarytool"
#
#      Credentials never live in this repo. The app-specific password comes
#      from appleid.apple.com and belongs to the Apple ID rather than to any
#      single app, so one is enough for every project signed by this team.
#
# Output: dist/UsageOwl-<version>.dmg, notarized and stapled, ready to upload.
#
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "usage: ./release.sh <version>   e.g. ./release.sh 1.0.0" >&2
    exit 1
fi
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: version must be X.Y.Z (the updater parses it as semver)" >&2
    exit 1
fi

APP_NAME="UsageOwl"
KEYCHAIN_PROFILE="notarytool"

echo "==> Building ${APP_NAME} ${VERSION}"
VERSION="$VERSION" ./build_app.sh

APP_PATH="dist/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

# Assemble the DMG outside the Desktop. Anything under a FileProvider-synced
# directory picks up com.apple.FinderInfo, which notarization rejects outright.
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
DMG_ROOT="$STAGING/dmg"
mkdir -p "$DMG_ROOT"

echo "==> Staging disk image contents"
cp -R "$APP_PATH" "$DMG_ROOT/${APP_NAME}.app"
ln -s /Applications "$DMG_ROOT/Applications"   # drag-to-install target
xattr -cr "$DMG_ROOT/${APP_NAME}.app"

# The signature must survive the copy — verify before spending a notarization round trip.
codesign --verify --deep --strict "$DMG_ROOT/${APP_NAME}.app"

echo "==> Creating $DMG_NAME"
DMG_PATH="$STAGING/$DMG_NAME"
hdiutil create -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH" >/dev/null

# Sign the disk image itself, not just the app inside it.
SIGNING_IDENTITY=$(security find-identity -v -p codesigning \
    | grep "Developer ID Application" | head -1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
if [ -z "$SIGNING_IDENTITY" ]; then
    echo "error: no Developer ID Application certificate found" >&2
    exit 1
fi
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"

# Two ways to authenticate, in preference order:
#
#   1. APPLE_ID / APPLE_PASSWORD / APPLE_TEAM_ID environment variables. This is
#      the same convention the Sitful project uses, so one exported set of
#      credentials covers both. APPLE_PASSWORD is an app-specific password from
#      appleid.apple.com — it belongs to the Apple ID, not to any one app, so
#      the one created for Sitful notarization works here unchanged.
#   2. A stored notarytool keychain profile.
#
# Nothing is ever echoed: the password reaches notarytool through the
# environment and is never printed, logged, or written to disk by this script.
NOTARY_ARGS=()
if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
    echo "==> Notarizing with APPLE_ID environment credentials (${APPLE_ID})"
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID")
elif xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
    echo "==> Notarizing with stored keychain profile \"$KEYCHAIN_PROFILE\""
    NOTARY_ARGS=(--keychain-profile "$KEYCHAIN_PROFILE")
else
    mkdir -p dist
    cp "$DMG_PATH" "dist/$DMG_NAME"
    xattr -cr "dist/$DMG_NAME" 2>/dev/null || true
    cat >&2 <<EOF

==> SIGNED BUT NOT NOTARIZED

  dist/$DMG_NAME

No Apple credentials were found, so the disk image was signed but never
submitted to Apple. Gatekeeper will refuse to open it on other people's Macs
("Apple cannot check it for malicious software"). Do NOT publish this build.

Provide credentials either way, then re-run:

  # A — environment variables (same as the Sitful project)
  export APPLE_ID="hello@seoforger.com"
  export APPLE_PASSWORD="abcd-efgh-ijkl-mnop"   # app-specific password
  export APPLE_TEAM_ID="2CL3959UYK"

  # B — stored once in the Keychain, then no env vars needed
  xcrun notarytool store-credentials "$KEYCHAIN_PROFILE"

EOF
    exit 2
fi

echo "==> Submitting to Apple for notarization (this takes a few minutes)"
xcrun notarytool submit "$DMG_PATH" "${NOTARY_ARGS[@]}" --wait

echo "==> Stapling the ticket"
xcrun stapler staple "$DMG_PATH"

mkdir -p dist
cp "$DMG_PATH" "dist/$DMG_NAME"
xattr -cr "dist/$DMG_NAME" 2>/dev/null || true

echo "==> Verifying as Gatekeeper will see it"
xcrun stapler validate "dist/$DMG_NAME"
spctl -a -t open --context context:primary-signature -vv "dist/$DMG_NAME"

cat <<EOF

==> DONE

  dist/$DMG_NAME

Publish it (the tag MUST be v${VERSION} — the in-app updater compares the
release tag against CFBundleShortVersionString):

  gh release create v${VERSION} "dist/$DMG_NAME" \\
    --title "UsageOwl ${VERSION}" --notes "..."

EOF
