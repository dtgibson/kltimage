#!/bin/bash

set -euo pipefail

readonly EXPECTED_IDENTITY="Developer ID Application: DAVID THOMAS GIBSON (8QKC3L2FKP)"
readonly EXPECTED_TEAM="8QKC3L2FKP"
readonly EXPECTED_VERSION="1.3.2"
readonly EXPECTED_BUILD="8"
readonly EXPECTED_APP_IDENTIFIER="com.kltimage.mac"
readonly EXPECTED_FRAMEWORK_IDENTIFIER="com.kltimage.core"

fail() {
    printf 'release verification failed: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: %s /path/to/KLT-Image-1.3.2-build-8.zip EXPECTED_SHA256\n' "$(basename "$0")" >&2
}

[[ $# -eq 2 ]] || {
    usage
    exit 64
}

readonly ARCHIVE="$1"
readonly EXPECTED_SHA256="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"

[[ -f "$ARCHIVE" ]] || fail "archive does not exist: $ARCHIVE"
[[ "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail "expected SHA-256 must be exactly 64 hexadecimal characters"

readonly ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] || fail "checksum mismatch (expected $EXPECTED_SHA256, got $ACTUAL_SHA256)"

readonly VERIFY_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kltimage-release-verify.XXXXXX")"
trap 'rm -rf "$VERIFY_ROOT"' EXIT

ditto -x -k "$ARCHIVE" "$VERIFY_ROOT"

readonly APP="$VERIFY_ROOT/KLT Image.app"
readonly FRAMEWORK="$APP/Contents/Frameworks/KLTCore.framework"
readonly APP_EXECUTABLE="$APP/Contents/MacOS/KLT Image"
readonly FRAMEWORK_EXECUTABLE="$FRAMEWORK/Versions/A/KLTCore"

[[ -d "$APP" ]] || fail "archive does not contain KLT Image.app at its root"
[[ -d "$FRAMEWORK" ]] || fail "archive is missing KLTCore.framework"
[[ -x "$APP_EXECUTABLE" ]] || fail "archive is missing the app executable"
[[ -f "$FRAMEWORK_EXECUTABLE" ]] || fail "archive is missing the framework executable"

readonly TOP_LEVEL_COUNT="$(find "$VERIFY_ROOT" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
[[ "$TOP_LEVEL_COUNT" == "1" ]] || fail "archive must contain only KLT Image.app at its root"

assert_universal_binary() {
    local binary="$1"
    local label="$2"
    local archs
    archs="$(lipo -archs "$binary")"
    [[ " $archs " == *" arm64 "* ]] || fail "$label is missing arm64"
    [[ " $archs " == *" x86_64 "* ]] || fail "$label is missing x86_64"
    [[ "$(printf '%s\n' "$archs" | wc -w | tr -d ' ')" == "2" ]] || fail "$label contains unexpected architectures: $archs"
}

assert_signature_metadata() {
    local bundle="$1"
    local identifier="$2"
    local label="$3"
    local metadata
    metadata="$(codesign -dvvv "$bundle" 2>&1)"

    printf '%s\n' "$metadata" | rg -q -F "Identifier=$identifier" || fail "$label has the wrong signing identifier"
    printf '%s\n' "$metadata" | rg -q -F "Authority=$EXPECTED_IDENTITY" || fail "$label is not signed by the required Developer ID identity"
    printf '%s\n' "$metadata" | rg -q -F "TeamIdentifier=$EXPECTED_TEAM" || fail "$label has the wrong TeamIdentifier"
    printf '%s\n' "$metadata" | rg -q '^Timestamp=.' || fail "$label has no secure signing timestamp"
    printf '%s\n' "$metadata" | rg -q '^Timestamp=none$' && fail "$label has an explicitly disabled timestamp"
    printf '%s\n' "$metadata" | rg -q 'flags=.*runtime' || fail "$label is missing the hardened-runtime signature flag"
    printf '%s\n' "$metadata" | rg -q 'Signature=adhoc' && fail "$label is ad-hoc signed"
    return 0
}

assert_universal_binary "$APP_EXECUTABLE" "app executable"
assert_universal_binary "$FRAMEWORK_EXECUTABLE" "framework executable"

[[ "$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")" == "$EXPECTED_VERSION" ]] || fail "wrong marketing version"
[[ "$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist")" == "$EXPECTED_BUILD" ]] || fail "wrong build number"

codesign --verify --strict --verbose=2 "$FRAMEWORK"
codesign --verify --deep --strict --verbose=2 "$APP"
assert_signature_metadata "$FRAMEWORK" "$EXPECTED_FRAMEWORK_IDENTIFIER" "KLTCore.framework"
assert_signature_metadata "$APP" "$EXPECTED_APP_IDENTIFIER" "KLT Image.app"

readonly ENTITLEMENTS_PLIST="$VERIFY_ROOT/app-entitlements.plist"
codesign -d --entitlements "$ENTITLEMENTS_PLIST" --xml "$APP" >/dev/null 2>&1
[[ -s "$ENTITLEMENTS_PLIST" ]] || fail "app signature has no entitlements"
[[ "$(plutil -extract 'com\.apple\.security\.app-sandbox' raw "$ENTITLEMENTS_PLIST")" == "true" ]] || fail "app sandbox entitlement is missing"
[[ "$(plutil -extract 'com\.apple\.security\.files\.user-selected\.read-write' raw "$ENTITLEMENTS_PLIST")" == "true" ]] || fail "user-selected-file entitlement is missing"
[[ "$(plutil -convert xml1 -o - "$ENTITLEMENTS_PLIST" | rg -c '<key>')" == "2" ]] || fail "app signature contains unexpected entitlements"
if plutil -extract 'com\.apple\.security\.get-task-allow' raw "$ENTITLEMENTS_PLIST" >/dev/null 2>&1; then
    fail "get-task-allow must not be present in a release"
fi
readonly FRAMEWORK_ENTITLEMENTS_PLIST="$VERIFY_ROOT/framework-entitlements.plist"
codesign -d --entitlements "$FRAMEWORK_ENTITLEMENTS_PLIST" --xml "$FRAMEWORK" >/dev/null 2>&1
[[ ! -s "$FRAMEWORK_ENTITLEMENTS_PLIST" ]] || fail "KLTCore.framework must not carry entitlements"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun stapler validate "$APP"

xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");KLT Image release verification;$(uuidgen)" "$APP"
xattr -p com.apple.quarantine "$APP" >/dev/null || fail "could not apply quarantine to verification copy"

readonly SPCTL_OUTPUT="$VERIFY_ROOT/spctl.txt"
if ! spctl --assess --type execute --verbose=4 "$APP" >"$SPCTL_OUTPUT" 2>&1; then
    sed -n '1,20p' "$SPCTL_OUTPUT" >&2
    fail "Gatekeeper rejected the quarantined app"
fi
rg -q 'accepted' "$SPCTL_OUTPUT" || fail "Gatekeeper did not report acceptance"
rg -q 'source=Notarized Developer ID' "$SPCTL_OUTPUT" || fail "Gatekeeper acceptance was not sourced from Notarized Developer ID"

printf 'Verified KLT Image %s (%s): universal, Developer ID-signed, notarized, stapled, quarantined, and Gatekeeper accepted.\n' "$EXPECTED_VERSION" "$EXPECTED_BUILD"
printf 'SHA-256: %s\n' "$ACTUAL_SHA256"
