#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
BUNDLE_ID="com.biwakonbu.MimoDesktopPet"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
VERSION=""
BUILD_NUMBER="${MIMO_APP_BUILD:-1}"
IDENTITY="${MIMO_CODESIGN_IDENTITY:-}"
NOTARIZE=0
NOTARY_PROFILE="${MIMO_NOTARY_KEYCHAIN_PROFILE:-${MIMO_NOTARY_PROFILE:-}}"
ASC_KEY_PATH="${MIMO_NOTARY_ASC_KEY_PATH:-${MIMO_ASC_KEY_PATH:-}}"
ASC_KEY_ID="${MIMO_NOTARY_ASC_KEY_ID:-${MIMO_ASC_KEY_ID:-}}"
ASC_ISSUER_ID="${MIMO_NOTARY_ASC_ISSUER_ID:-${MIMO_ASC_ISSUER_ID:-}}"

usage() {
  cat >&2 <<USAGE
usage: $0 <version> [--notarize] [--notary-profile <profile>]
       $0 <version> --notarize --asc-key <AuthKey.p8> --asc-key-id <key-id> [--asc-issuer <issuer-id>]

Environment:
  MIMO_CODESIGN_IDENTITY          Developer ID Application identity override
  MIMO_APP_BUILD                  CFBundleVersion override (default: 1)
  MIMO_NOTARY_KEYCHAIN_PROFILE    notarytool keychain profile name
  MIMO_NOTARY_ASC_KEY_PATH        App Store Connect API key .p8 path
  MIMO_NOTARY_ASC_KEY_ID          App Store Connect API key ID
  MIMO_NOTARY_ASC_ISSUER_ID       App Store Connect issuer ID for team keys
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarize)
      NOTARIZE=1
      shift
      ;;
    --notary-profile)
      if [[ $# -lt 2 ]]; then
        usage
        exit 2
      fi
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --asc-key)
      if [[ $# -lt 2 ]]; then
        usage
        exit 2
      fi
      ASC_KEY_PATH="$2"
      shift 2
      ;;
    --asc-key-id)
      if [[ $# -lt 2 ]]; then
        usage
        exit 2
      fi
      ASC_KEY_ID="$2"
      shift 2
      ;;
    --asc-issuer)
      if [[ $# -lt 2 ]]; then
        usage
        exit 2
      fi
      ASC_ISSUER_ID="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$VERSION" ]]; then
        VERSION="$1"
        shift
      else
        usage
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  usage
  exit 2
fi

if [[ ! "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([.-][A-Za-z0-9]+)?$ ]]; then
  echo "version must look like 0.0.1, got: $VERSION" >&2
  exit 2
fi

declare -a NOTARY_AUTH_ARGS=()
if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -n "$NOTARY_PROFILE" && ( -n "$ASC_KEY_PATH" || -n "$ASC_KEY_ID" || -n "$ASC_ISSUER_ID" ) ]]; then
    echo "choose either --notary-profile or App Store Connect API key options, not both" >&2
    exit 2
  fi

  if [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARY_AUTH_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  elif [[ -n "$ASC_KEY_PATH" || -n "$ASC_KEY_ID" || -n "$ASC_ISSUER_ID" ]]; then
    if [[ -z "$ASC_KEY_PATH" || -z "$ASC_KEY_ID" ]]; then
      echo "App Store Connect API notarization requires --asc-key and --asc-key-id" >&2
      exit 2
    fi
    if [[ ! -f "$ASC_KEY_PATH" ]]; then
      echo "App Store Connect API key file not found: $ASC_KEY_PATH" >&2
      exit 1
    fi
    NOTARY_AUTH_ARGS=(--key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID")
    if [[ -n "$ASC_ISSUER_ID" ]]; then
      NOTARY_AUTH_ARGS+=(--issuer "$ASC_ISSUER_ID")
    fi
  else
    echo "notarization requested but no notary authentication was supplied" >&2
    echo "pass --notary-profile <profile> or --asc-key <AuthKey.p8> --asc-key-id <key-id> [--asc-issuer <issuer-id>]" >&2
    exit 2
  fi
fi

DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release/v$VERSION"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
DMG_ROOT="$RELEASE_DIR/dmg-root"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
PET_SOURCE_DIR="$REPO_ROOT/pets/mimo"
PET_RESOURCE_DIR="$APP_RESOURCES/pets/mimo"

cd "$ROOT_DIR"

if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(
    security find-identity -p codesigning -v |
      sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' |
      head -n 1
  )"
fi

if [[ -z "$IDENTITY" ]]; then
  echo "no Developer ID Application signing identity found" >&2
  echo "install a Developer ID Application certificate or set MIMO_CODESIGN_IDENTITY" >&2
  exit 1
fi

echo "Building $APP_NAME $VERSION for release..."
swift build -c release --product "$APP_NAME"
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

rm -rf "$RELEASE_DIR"
mkdir -p "$APP_MACOS" "$PET_RESOURCE_DIR"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$PET_SOURCE_DIR/pet.json" "$PET_RESOURCE_DIR/pet.json"
cp "$PET_SOURCE_DIR/spritesheet.webp" "$PET_RESOURCE_DIR/spritesheet.webp"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Mimo Desktop Pet</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ ! -s "$PET_RESOURCE_DIR/pet.json" || ! -s "$PET_RESOURCE_DIR/spritesheet.webp" ]]; then
  echo "failed to stage non-empty Mimo pet resources into $PET_RESOURCE_DIR" >&2
  exit 1
fi

echo "Signing app with: $IDENTITY"
codesign --force --timestamp --options runtime --sign "$IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
codesign -dvvv --entitlements :- "$APP_BUNDLE" >/dev/null 2>&1 || true

rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

echo "Creating DMG: $DMG_PATH"
hdiutil create \
  -volname "Mimo Desktop Pet $VERSION" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Signing DMG..."
codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "Submitting DMG for notarization with profile: $NOTARY_PROFILE"
  else
    echo "Submitting DMG for notarization with App Store Connect API key: $ASC_KEY_ID"
  fi
  xcrun notarytool submit "$DMG_PATH" "${NOTARY_AUTH_ARGS[@]}" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
else
  echo "Skipping notarization. Pass --notarize with a notarytool profile or App Store Connect API key to staple a ticket."
fi

shasum -a 256 "$DMG_PATH" >"$CHECKSUM_PATH"
rm -rf "$DMG_ROOT"

echo "Release artifacts:"
echo "  $DMG_PATH"
echo "  $CHECKSUM_PATH"
