#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)}"
RELEASE_BUILD="${RELEASE_BUILD:-0}"
UNIVERSAL_BUILD="${UNIVERSAL_BUILD:-1}"
ARM64_SCRATCH="$ROOT_DIR/.build/tokenbar-arm64"
X86_64_SCRATCH="$ROOT_DIR/.build/tokenbar-x86_64"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/TokenBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_PATH="$DIST_DIR/TokenBar.dmg"
STAGING_DIR="$DIST_DIR/dmg-root"
TMP_DMG_PATH="$DIST_DIR/TokenBar.rw.dmg"
INSTALLER_ASSETS_DIR="$DIST_DIR/installer-assets"
NOTARY_ZIP="$DIST_DIR/TokenBar-notary.zip"
VOLUME_NAME="TokenBar Installer"
MOUNT_DIR=""

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid VERSION: $VERSION" >&2
  exit 2
fi

if [[ "$RELEASE_BUILD" == "1" && -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "RELEASE_BUILD=1 requires DEVELOPER_ID_APPLICATION." >&2
  exit 2
fi

if [[ "$RELEASE_BUILD" == "1" \
  && -z "${NOTARYTOOL_PROFILE:-}" \
  && -z "${NOTARY_API_KEY_PATH:-}" \
  && (-z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}") ]]; then
  echo "RELEASE_BUILD=1 requires notarization credentials." >&2
  exit 2
fi

cleanup_mount() {
  if [[ -n "${MOUNT_DIR:-}" ]] && mount | grep -Fq " on $MOUNT_DIR "; then
    hdiutil detach "$MOUNT_DIR" >/dev/null || true
  fi
}
trap cleanup_mount EXIT

notarize() {
  local artifact="$1"
  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    xcrun notarytool submit "$artifact" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  elif [[ -n "${NOTARY_API_KEY_PATH:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]]; then
    xcrun notarytool submit "$artifact" \
      --key "$NOTARY_API_KEY_PATH" \
      --key-id "$NOTARY_KEY_ID" \
      --issuer "$NOTARY_ISSUER_ID" \
      --wait
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$artifact" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
  else
    echo "Release notarization requires a notarytool profile, Team API key, or Apple ID credentials." >&2
    exit 2
  fi
}

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [[ "$UNIVERSAL_BUILD" == "1" ]]; then
  swift build -c release --product TokenBarApp \
    --package-path "$ROOT_DIR" \
    --triple arm64-apple-macosx14.0 \
    --scratch-path "$ARM64_SCRATCH"
  swift build -c release --product TokenBarApp \
    --package-path "$ROOT_DIR" \
    --triple x86_64-apple-macosx14.0 \
    --scratch-path "$X86_64_SCRATCH"
  lipo -create \
    "$ARM64_SCRATCH/arm64-apple-macosx/release/TokenBarApp" \
    "$X86_64_SCRATCH/x86_64-apple-macosx/release/TokenBarApp" \
    -output "$MACOS_DIR/TokenBar"
  chmod 755 "$MACOS_DIR/TokenBar"
else
  swift build -c release --product TokenBarApp --package-path "$ROOT_DIR"
  install -m 755 "$ROOT_DIR/.build/release/TokenBarApp" "$MACOS_DIR/TokenBar"
fi

swift "$ROOT_DIR/Scripts/generate-installer-assets.swift" "$INSTALLER_ASSETS_DIR"
iconutil -c icns "$INSTALLER_ASSETS_DIR/TokenBar.iconset" -o "$RESOURCES_DIR/TokenBar.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>TokenBar</string>
  <key>CFBundleIdentifier</key>
  <string>com.tokenbar.TokenBar</string>
  <key>CFBundleName</key>
  <string>TokenBar</string>
  <key>CFBundleDisplayName</key>
  <string>TokenBar</string>
  <key>CFBundleIconFile</key>
  <string>TokenBar.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 TokenBar contributors. MIT License.</string>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null
if [[ "$UNIVERSAL_BUILD" == "1" ]]; then
  lipo "$MACOS_DIR/TokenBar" -verify_arch x86_64 arm64
fi

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --deep --options runtime --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" "$APP_DIR"
else
  codesign --force --deep --sign - "$APP_DIR"
fi
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

if [[ "$RELEASE_BUILD" == "1" ]]; then
  ditto -c -k --keepParent "$APP_DIR" "$NOTARY_ZIP"
  notarize "$NOTARY_ZIP"
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
  spctl --assess --type execute --verbose=2 "$APP_DIR"
  rm -f "$NOTARY_ZIP"
fi

mkdir -p "$STAGING_DIR/.background"
cp -R "$APP_DIR" "$STAGING_DIR/"
cp "$INSTALLER_ASSETS_DIR/TokenBar Installer.png" "$STAGING_DIR/.background/"
cp "$RESOURCES_DIR/TokenBar.icns" "$STAGING_DIR/.VolumeIcon.icns"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -fs HFS+ \
  -format UDRW \
  "$TMP_DMG_PATH"

if [[ -d "/Volumes/$VOLUME_NAME" ]]; then
  hdiutil detach "/Volumes/$VOLUME_NAME" >/dev/null 2>&1 || true
fi

ATTACH_OUTPUT="$(hdiutil attach "$TMP_DMG_PATH" -readwrite -noverify -noautoopen)"
MOUNT_DIR="$(printf "%s\n" "$ATTACH_OUTPUT" | awk -F '\t' '/\/Volumes\// {print $NF; exit}')"
if [[ -z "$MOUNT_DIR" ]]; then
  echo "Failed to mount DMG." >&2
  echo "$ATTACH_OUTPUT" >&2
  exit 1
fi

SETFILE="$(xcrun --find SetFile 2>/dev/null || true)"
if [[ -n "$SETFILE" ]]; then
  "$SETFILE" -a C "$MOUNT_DIR"
  "$SETFILE" -a V "$MOUNT_DIR/.VolumeIcon.icns"
fi

osascript - "$VOLUME_NAME" <<'APPLESCRIPT'
on run argv
set volumeName to item 1 of argv
tell application "Finder"
  tell disk volumeName
    open
    set current view of container window to icon view
    set installerWindow to container window
    try
      set toolbar visible of installerWindow to false
      set statusbar visible of installerWindow to false
      set pathbar visible of installerWindow to false
    end try
    set bounds of installerWindow to {120, 120, 780, 542}
    set viewOptions to icon view options of installerWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 160
    set text size of viewOptions to 14
    set background picture of viewOptions to file ".background:TokenBar Installer.png"
    set position of item "TokenBar.app" of installerWindow to {330, 240}
    select item "TokenBar.app" of installerWindow
    delay 1
    close installerWindow
  end tell
end tell
end run
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" >/dev/null
MOUNT_DIR=""

hdiutil convert "$TMP_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" \
  -ov >/dev/null

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ "$RELEASE_BUILD" == "1" ]]; then
  notarize "$DMG_PATH"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH" >/dev/null
(
  cd "$DIST_DIR"
  shasum -a 256 TokenBar.dmg > SHA256SUMS
)

rm -rf "$STAGING_DIR" "$TMP_DMG_PATH" "$INSTALLER_ASSETS_DIR"
echo "Created TokenBar $VERSION ($BUILD_NUMBER): $DMG_PATH"
