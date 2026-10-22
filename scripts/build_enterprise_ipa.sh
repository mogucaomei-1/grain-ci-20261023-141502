#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/outputs/GRAIN/GRAIN.xcodeproj}"
SCHEME="${SCHEME:-GRAIN}"
BUNDLE_ID="${BUNDLE_ID:-studio.grain.rawfilm}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
BUILD_CERTIFICATE_BASE64="${BUILD_CERTIFICATE_BASE64:-}"
P12_PASSWORD="${P12_PASSWORD:-}"
PROVISIONING_PROFILE_BASE64="${PROVISIONING_PROFILE_BASE64:-}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

for required in APPLE_TEAM_ID BUILD_CERTIFICATE_BASE64 P12_PASSWORD PROVISIONING_PROFILE_BASE64; do
  if [[ -z "${!required:-}" ]]; then
    echo "Missing required environment variable: $required" >&2
    exit 2
  fi
done

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Xcode project not found: $PROJECT_PATH" >&2
  exit 2
fi

BUILD_DIR="$ROOT_DIR/ci/build"
ARTIFACT_DIR="$ROOT_DIR/ci/artifacts"
DERIVED_DATA="$ROOT_DIR/ci/DerivedData"
ARCHIVE_PATH="$BUILD_DIR/GRAIN.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
CERT_PATH="$BUILD_DIR/enterprise-signing.p12"
PROFILE_PATH="$BUILD_DIR/enterprise.mobileprovision"
PROFILE_PLIST="$BUILD_DIR/enterprise-profile.plist"
KEYCHAIN_PATH="$BUILD_DIR/app-signing.keychain-db"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-$(openssl rand -hex 24)}"

mkdir -p "$BUILD_DIR" "$ARTIFACT_DIR" "$DERIVED_DATA"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$KEYCHAIN_PATH"
mkdir -p "$EXPORT_PATH"

cleanup() {
  /usr/bin/security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  rm -f "$CERT_PATH"
}
trap cleanup EXIT

printf '%s' "$BUILD_CERTIFICATE_BASE64" | /usr/bin/base64 -D > "$CERT_PATH"
printf '%s' "$PROVISIONING_PROFILE_BASE64" | /usr/bin/base64 -D > "$PROFILE_PATH"

/usr/bin/security cms -D -i "$PROFILE_PATH" > "$PROFILE_PLIST"
/usr/bin/plutil -lint "$PROFILE_PLIST"

PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print :UUID" "$PROFILE_PLIST")
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" "$PROFILE_PLIST")
PROFILE_TEAM_ID=$(/usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" "$PROFILE_PLIST")
PROFILE_EXPIRATION=$(/usr/libexec/PlistBuddy -c "Print :ExpirationDate" "$PROFILE_PLIST")
PROFILE_APP_ID=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$PROFILE_PLIST")

if [[ "$PROFILE_TEAM_ID" != "$APPLE_TEAM_ID" ]]; then
  echo "Team mismatch: profile is for $PROFILE_TEAM_ID, secret APPLE_TEAM_ID is $APPLE_TEAM_ID" >&2
  exit 3
fi

EXPECTED_APP_ID="$APPLE_TEAM_ID.$BUNDLE_ID"
if [[ "$PROFILE_APP_ID" != "$EXPECTED_APP_ID" && "$PROFILE_APP_ID" != "$APPLE_TEAM_ID.*" ]]; then
  echo "Bundle ID mismatch: profile allows $PROFILE_APP_ID, but BUNDLE_ID is $EXPECTED_APP_ID" >&2
  exit 3
fi

PROFILE_INSTALL_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROFILE_INSTALL_DIR"
cp "$PROFILE_PATH" "$PROFILE_INSTALL_DIR/$PROFILE_UUID.mobileprovision"

/usr/bin/security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
/usr/bin/security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
/usr/bin/security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
/usr/bin/security import "$CERT_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$P12_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12
/usr/bin/security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH" >/dev/null

ORIGINAL_KEYCHAINS=()
while IFS= read -r keychain; do
  keychain=$(echo "$keychain" | sed -e 's/^[[:space:]]*//' -e 's/^"//' -e 's/"$//')
  [[ -n "$keychain" ]] && ORIGINAL_KEYCHAINS+=("$keychain")
done < <(/usr/bin/security list-keychains -d user)
/usr/bin/security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" "$KEYCHAIN_PATH"

CERTIFICATE_IDENTITIES=$(/usr/bin/security find-identity -v -p codesigning "$KEYCHAIN_PATH" | sed -n 's/.*"\(.*\)"/\1/p')
if [[ -z "$CERTIFICATE_IDENTITIES" ]]; then
  echo "No valid signing identity was imported from the .p12 file." >&2
  exit 4
fi

if [[ -n "$SIGNING_IDENTITY" ]] && ! grep -Fq "$SIGNING_IDENTITY" <<< "$CERTIFICATE_IDENTITIES"; then
  echo "Requested signing identity is not in the keychain: $SIGNING_IDENTITY" >&2
  echo "$CERTIFICATE_IDENTITIES" >&2
  exit 4
fi

EXPORT_OPTIONS="$EXPORT_PATH/ExportOptions.plist"
/usr/bin/plutil -create xml1 "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :method string enterprise" "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :signingStyle string manual" "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :teamID string $APPLE_TEAM_ID" "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :destination string export" "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :stripSwiftSymbols bool true" "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :compileBitcode bool false" "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :manageAppVersionAndBuildNumber bool false" "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$BUNDLE_ID string $PROFILE_NAME" "$EXPORT_OPTIONS"

SIGN_ARGS=(
  "CODE_SIGN_STYLE=Manual"
  "DEVELOPMENT_TEAM=$APPLE_TEAM_ID"
  "PROVISIONING_PROFILE_SPECIFIER=$PROFILE_NAME"
  "PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID"
  "CURRENT_PROJECT_VERSION=$BUILD_NUMBER"
)
if [[ -n "$SIGNING_IDENTITY" ]]; then
  SIGN_ARGS+=("CODE_SIGN_IDENTITY=$SIGNING_IDENTITY")
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA" \
  "${SIGN_ARGS[@]}" \
  archive | tee "$BUILD_DIR/archive.log"

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" | tee "$BUILD_DIR/export.log"

IPA_PATH=$(find "$EXPORT_PATH" -maxdepth 1 -type f -name "*.ipa" -print -quit)
if [[ -z "$IPA_PATH" ]]; then
  echo "xcodebuild completed but no IPA was exported." >&2
  exit 5
fi

CHECK_DIR="$BUILD_DIR/ipa-check"
rm -rf "$CHECK_DIR"
mkdir -p "$CHECK_DIR"
unzip -q "$IPA_PATH" -d "$CHECK_DIR"
APP_PATH=$(find "$CHECK_DIR/Payload" -maxdepth 1 -type d -name "*.app" -print -quit)
if [[ -z "$APP_PATH" ]]; then
  echo "IPA does not contain a Payload/*.app bundle." >&2
  exit 5
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
APP_PROFILE_PLIST="$BUILD_DIR/app-embedded-profile.plist"
/usr/bin/security cms -D -i "$APP_PATH/embedded.mobileprovision" > "$APP_PROFILE_PLIST"
APP_PROFILE_TEAM_ID=$(/usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" "$APP_PROFILE_PLIST")
if [[ "$APP_PROFILE_TEAM_ID" != "$APPLE_TEAM_ID" ]]; then
  echo "Exported app is signed with an unexpected team: $APP_PROFILE_TEAM_ID" >&2
  exit 6
fi

ARTIFACT_IPA="$ARTIFACT_DIR/GRAIN-enterprise-${BUILD_NUMBER}.ipa"
cp "$IPA_PATH" "$ARTIFACT_IPA"

{
  echo "product=GRAIN"
  echo "bundle_id=$BUNDLE_ID"
  echo "team_id=$APPLE_TEAM_ID"
  echo "profile_name=$PROFILE_NAME"
  echo "profile_expiration=$PROFILE_EXPIRATION"
  echo "distribution_profile_all_devices=$(/usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$PROFILE_PLIST" 2>/dev/null || echo false)"
  echo "build_number=$BUILD_NUMBER"
  echo "ipa=$(basename "$ARTIFACT_IPA")"
  echo "architectures=$('/usr/bin/lipo' -archs "$APP_PATH/$SCHEME")"
} > "$ARTIFACT_DIR/build-info.txt"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "ipa_path=$ARTIFACT_IPA" >> "$GITHUB_OUTPUT"
  echo "ipa_name=$(basename "$ARTIFACT_IPA")" >> "$GITHUB_OUTPUT"
fi

echo "Signed enterprise IPA: $ARTIFACT_IPA"
cat "$ARTIFACT_DIR/build-info.txt"

