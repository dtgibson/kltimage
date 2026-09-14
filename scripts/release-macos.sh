#!/bin/bash

set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly PROJECT="$REPO_ROOT/KLTImage.xcodeproj"
readonly SCHEME="KLTImage"
readonly EXPECTED_IDENTITY="Developer ID Application: DAVID THOMAS GIBSON (8QKC3L2FKP)"
readonly EXPECTED_TEAM="8QKC3L2FKP"
readonly EXPECTED_VERSION="1.3.2"
readonly EXPECTED_BUILD="8"
readonly EXPECTED_APP_IDENTIFIER="com.kltimage.mac"
readonly EXPECTED_FRAMEWORK_IDENTIFIER="com.kltimage.core"
readonly RELEASE_NAME="KLT-Image-${EXPECTED_VERSION}-build-${EXPECTED_BUILD}.zip"
readonly RELEASE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kltimage-release.XXXXXX")"
readonly DERIVED_DATA="$RELEASE_ROOT/DerivedData"
readonly BUILD_LOG="$RELEASE_ROOT/xcodebuild.log"
readonly STAGE_ROOT="$RELEASE_ROOT/stage"
readonly APP="$STAGE_ROOT/KLT Image.app"
readonly FRAMEWORK="$APP/Contents/Frameworks/KLTCore.framework"
readonly APP_EXECUTABLE="$APP/Contents/MacOS/KLT Image"
readonly FRAMEWORK_EXECUTABLE="$FRAMEWORK/Versions/A/KLTCore"
readonly NOTARY_UPLOAD="$RELEASE_ROOT/notary-upload.zip"
readonly NOTARY_RESULT="$RELEASE_ROOT/notary-result.json"
readonly PENDING_ARCHIVE="$RELEASE_ROOT/UNVERIFIED-${RELEASE_NAME}.pending"
readonly PENDING_CHECKSUM="$PENDING_ARCHIVE.sha256.pending"
readonly VERIFIER_LOG="$RELEASE_ROOT/independent-verifier.log"
readonly FINAL_ARCHIVE="$RELEASE_ROOT/$RELEASE_NAME"
readonly CHECKSUM_FILE="$FINAL_ARCHIVE.sha256"

NOTARY_PROFILE=""
NOTARY_KEY=""
NOTARY_KEY_ID=""
NOTARY_ISSUER=""
PROMOTION_SELF_TEST="false"

fail() {
    printf 'release failed: %s\n' "$*" >&2
    printf 'release workspace retained at: %s\n' "$RELEASE_ROOT" >&2
    exit 1
}

usage() {
    printf 'Usage:\n'
    printf '  %s --notary-profile KEYCHAIN_PROFILE\n' "$(basename "$0")"
    printf '  %s --notary-key PRIVATE_KEY_PATH --notary-key-id KEY_ID --notary-issuer ISSUER_UUID\n' "$(basename "$0")"
    printf '  %s --self-test-promotion\n' "$(basename "$0")"
    printf 'Without either complete credential mode, the script builds and verifies a Developer ID-signed candidate, then stops before notarization.\n'
}

run_release_verifier() {
    "$REPO_ROOT/scripts/verify-macos-release.sh" "$1" "$2" >"$VERIFIER_LOG" 2>&1
}

promote_release_artifact() {
    local pending_archive="$1"
    local pending_checksum="$2"
    local final_archive="$3"
    local final_checksum="$4"
    local expected_sha256="$5"

    [[ -f "$pending_archive" && -f "$pending_checksum" ]] || return 1
    [[ ! -e "$final_archive" && ! -e "$final_checksum" ]] || return 1
    run_release_verifier "$pending_archive" "$expected_sha256" || return 1

    # Both renames stay on the same temporary volume and are individually atomic.
    printf '%s  %s\n' "$expected_sha256" "$(basename "$final_archive")" >"$pending_checksum" || return 1
    mv "$pending_archive" "$final_archive" || return 1
    mv "$pending_checksum" "$final_checksum" || return 1
}

verify_and_promote_or_fail() {
    if ! promote_release_artifact "$1" "$2" "$3" "$4" "$5"; then
        [[ -f "$VERIFIER_LOG" ]] && sed -n '1,240p' "$VERIFIER_LOG" >&2
        fail "independent verification or atomic artifact promotion failed; final-named artifacts were not created before verifier acceptance"
    fi
    [[ -f "$VERIFIER_LOG" ]] && sed -n '1,240p' "$VERIFIER_LOG"
    return 0
}

run_promotion_self_test() {
    local self_test_root
    local failure_pending_archive
    local failure_pending_checksum
    local failure_final_archive
    local failure_final_checksum
    local success_pending_archive
    local success_pending_checksum
    local success_final_archive
    local success_final_checksum
    local fixture_sha256
    local failure_output

    self_test_root="$RELEASE_ROOT"
    trap 'rm -rf "$RELEASE_ROOT"' EXIT

    failure_pending_archive="$self_test_root/UNVERIFIED-failure.zip.pending"
    failure_pending_checksum="$failure_pending_archive.sha256.pending"
    failure_final_archive="$self_test_root/failure.zip"
    failure_final_checksum="$failure_final_archive.sha256"
    printf 'diagnostic fixture\n' >"$failure_pending_archive"
    fixture_sha256="$(shasum -a 256 "$failure_pending_archive" | awk '{print $1}')"
    printf '%s  %s\n' "$fixture_sha256" "$(basename "$failure_pending_archive")" >"$failure_pending_checksum"

    run_release_verifier() { return 1; }
    if failure_output="$(
        trap - EXIT
        verify_and_promote_or_fail "$failure_pending_archive" "$failure_pending_checksum" "$failure_final_archive" "$failure_final_checksum" "$fixture_sha256" 2>&1
    )"; then
        printf 'promotion self-test failed: rejected verifier unexpectedly promoted an artifact\n' >&2
        exit 1
    fi
    printf '%s\n' "$failure_output" | rg -q -F 'release failed: independent verification or atomic artifact promotion failed' || {
        printf 'promotion self-test failed: verifier rejection bypassed the release failure path\n' >&2
        exit 1
    }
    [[ -f "$failure_pending_archive" && -f "$failure_pending_checksum" ]] || {
        printf 'promotion self-test failed: rejected pending diagnostics were not retained\n' >&2
        exit 1
    }
    [[ ! -e "$failure_final_archive" && ! -e "$failure_final_checksum" ]] || {
        printf 'promotion self-test failed: final-named artifacts survived verifier failure\n' >&2
        exit 1
    }

    success_pending_archive="$self_test_root/UNVERIFIED-success.zip.pending"
    success_pending_checksum="$success_pending_archive.sha256.pending"
    success_final_archive="$self_test_root/success.zip"
    success_final_checksum="$success_final_archive.sha256"
    printf 'verified fixture\n' >"$success_pending_archive"
    fixture_sha256="$(shasum -a 256 "$success_pending_archive" | awk '{print $1}')"
    printf '%s  %s\n' "$fixture_sha256" "$(basename "$success_pending_archive")" >"$success_pending_checksum"

    run_release_verifier() { return 0; }
    verify_and_promote_or_fail "$success_pending_archive" "$success_pending_checksum" "$success_final_archive" "$success_final_checksum" "$fixture_sha256"
    [[ ! -e "$success_pending_archive" && ! -e "$success_pending_checksum" ]] || {
        printf 'promotion self-test failed: pending names survived successful promotion\n' >&2
        exit 1
    }
    [[ -f "$success_final_archive" && -f "$success_final_checksum" ]] || {
        printf 'promotion self-test failed: final names are missing after accepted verification\n' >&2
        exit 1
    }
    (
        cd "$self_test_root"
        shasum -a 256 -c "$(basename "$success_final_checksum")" >/dev/null
    ) || {
        printf 'promotion self-test failed: promoted checksum does not name the final archive\n' >&2
        exit 1
    }

    printf 'Promotion self-test passed: verifier failure retained only pending diagnostics; success atomically promoted both final names.\n'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notary-profile)
            [[ $# -ge 2 && -n "$2" ]] || fail "--notary-profile requires a value"
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --notary-key)
            [[ $# -ge 2 && -n "$2" ]] || fail "--notary-key requires a value"
            NOTARY_KEY="$2"
            shift 2
            ;;
        --notary-key-id)
            [[ $# -ge 2 && -n "$2" ]] || fail "--notary-key-id requires a value"
            NOTARY_KEY_ID="$2"
            shift 2
            ;;
        --notary-issuer)
            [[ $# -ge 2 && -n "$2" ]] || fail "--notary-issuer requires a value"
            NOTARY_ISSUER="$2"
            shift 2
            ;;
        --self-test-promotion)
            PROMOTION_SELF_TEST="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "unknown argument: $1"
            ;;
    esac
done

if [[ "$PROMOTION_SELF_TEST" == "true" ]]; then
    [[ -z "$NOTARY_PROFILE" && -z "$NOTARY_KEY" && -z "$NOTARY_KEY_ID" && -z "$NOTARY_ISSUER" ]] || fail "promotion self-test cannot be combined with notarization credentials"
    run_promotion_self_test
    exit 0
fi

API_CREDENTIAL_FIELD_COUNT=0
[[ -n "$NOTARY_KEY" ]] && API_CREDENTIAL_FIELD_COUNT=$((API_CREDENTIAL_FIELD_COUNT + 1))
[[ -n "$NOTARY_KEY_ID" ]] && API_CREDENTIAL_FIELD_COUNT=$((API_CREDENTIAL_FIELD_COUNT + 1))
[[ -n "$NOTARY_ISSUER" ]] && API_CREDENTIAL_FIELD_COUNT=$((API_CREDENTIAL_FIELD_COUNT + 1))
[[ -z "$NOTARY_PROFILE" || "$API_CREDENTIAL_FIELD_COUNT" == "0" ]] || fail "choose either a Keychain profile or an API key, not both"
[[ "$API_CREDENTIAL_FIELD_COUNT" == "0" || "$API_CREDENTIAL_FIELD_COUNT" == "3" ]] || fail "API-key notarization requires --notary-key, --notary-key-id, and --notary-issuer together"
if [[ "$API_CREDENTIAL_FIELD_COUNT" == "3" ]]; then
    [[ -f "$NOTARY_KEY" && -r "$NOTARY_KEY" ]] || fail "notary private-key file is unavailable or unreadable"
    [[ "$NOTARY_KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "notary key ID must be 10 uppercase letters or digits"
    [[ "$NOTARY_ISSUER" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] || fail "notary issuer must be a UUID"
fi

for command_name in xcodegen xcodebuild xcrun codesign security ditto lipo plutil rg shasum xattr spctl mv; do
    command -v "$command_name" >/dev/null 2>&1 || fail "required command is unavailable: $command_name"
done
[[ -d /Applications/Xcode.app/Contents/Developer ]] || fail "full Xcode is unavailable at /Applications/Xcode.app"

printf 'Release workspace: %s\n' "$RELEASE_ROOT"

security find-identity -v -p codesigning | rg -q -F "\"$EXPECTED_IDENTITY\"" || fail "required Developer ID Application identity is unavailable"

cd "$REPO_ROOT"
xcodegen generate --spec "$REPO_ROOT/project.yml" --project "$REPO_ROOT"

readonly SOURCE_VERSION="$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project "$PROJECT" -target KLTImage -configuration Release -showBuildSettings | awk -F ' = ' '/^[[:space:]]*MARKETING_VERSION = / { print $2; exit }')"
readonly SOURCE_BUILD="$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project "$PROJECT" -target KLTImage -configuration Release -showBuildSettings | awk -F ' = ' '/^[[:space:]]*CURRENT_PROJECT_VERSION = / { print $2; exit }')"
[[ "$SOURCE_VERSION" == "$EXPECTED_VERSION" ]] || fail "project marketing version is $SOURCE_VERSION, expected $EXPECTED_VERSION"
[[ "$SOURCE_BUILD" == "$EXPECTED_BUILD" ]] || fail "project build number is $SOURCE_BUILD, expected $EXPECTED_BUILD"

if ! DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build >"$BUILD_LOG" 2>&1; then
    tail -80 "$BUILD_LOG" >&2
    fail "universal Release build failed"
fi
rg -q '\*\* BUILD SUCCEEDED \*\*' "$BUILD_LOG" || fail "xcodebuild did not report a successful build"

readonly BUILT_APP="$DERIVED_DATA/Build/Products/Release/KLT Image.app"
[[ -d "$BUILT_APP" ]] || fail "Release build did not produce KLT Image.app"
mkdir -p "$STAGE_ROOT"
ditto "$BUILT_APP" "$APP"

[[ -d "$FRAMEWORK" ]] || fail "Release app is missing KLTCore.framework"
[[ -x "$APP_EXECUTABLE" ]] || fail "Release app executable is missing"
[[ -f "$FRAMEWORK_EXECUTABLE" ]] || fail "KLTCore executable is missing"

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

[[ "$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")" == "$EXPECTED_VERSION" ]] || fail "built app has the wrong marketing version"
[[ "$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist")" == "$EXPECTED_BUILD" ]] || fail "built app has the wrong build number"

# Nested code must be sealed before its containing app bundle.
codesign --force --sign "$EXPECTED_IDENTITY" --options runtime --timestamp "$FRAMEWORK"
codesign --force --sign "$EXPECTED_IDENTITY" --options runtime --timestamp --entitlements "$REPO_ROOT/KLTImage/KLTImage.entitlements" "$APP"

codesign --verify --strict --verbose=2 "$FRAMEWORK"
codesign --verify --deep --strict --verbose=2 "$APP"
assert_signature_metadata "$FRAMEWORK" "$EXPECTED_FRAMEWORK_IDENTIFIER" "KLTCore.framework"
assert_signature_metadata "$APP" "$EXPECTED_APP_IDENTIFIER" "KLT Image.app"

readonly ENTITLEMENTS_PLIST="$RELEASE_ROOT/signed-app-entitlements.plist"
codesign -d --entitlements "$ENTITLEMENTS_PLIST" --xml "$APP" >/dev/null 2>&1
[[ -s "$ENTITLEMENTS_PLIST" ]] || fail "signed app has no entitlements"
[[ "$(plutil -extract 'com\.apple\.security\.app-sandbox' raw "$ENTITLEMENTS_PLIST")" == "true" ]] || fail "app sandbox entitlement is missing"
[[ "$(plutil -extract 'com\.apple\.security\.files\.user-selected\.read-write' raw "$ENTITLEMENTS_PLIST")" == "true" ]] || fail "user-selected-file entitlement is missing"
[[ "$(plutil -convert xml1 -o - "$ENTITLEMENTS_PLIST" | rg -c '<key>')" == "2" ]] || fail "signed app contains unexpected entitlements"
if plutil -extract 'com\.apple\.security\.get-task-allow' raw "$ENTITLEMENTS_PLIST" >/dev/null 2>&1; then
    fail "get-task-allow must not be present in a release"
fi
readonly FRAMEWORK_ENTITLEMENTS_PLIST="$RELEASE_ROOT/signed-framework-entitlements.plist"
codesign -d --entitlements "$FRAMEWORK_ENTITLEMENTS_PLIST" --xml "$FRAMEWORK" >/dev/null 2>&1
[[ ! -s "$FRAMEWORK_ENTITLEMENTS_PLIST" ]] || fail "KLTCore.framework must not carry entitlements"

printf 'Developer ID-signed candidate verified: %s\n' "$APP"

declare -a NOTARY_AUTH_ARGS
if [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARY_AUTH_ARGS=(--keychain-profile "$NOTARY_PROFILE")
elif [[ "$API_CREDENTIAL_FIELD_COUNT" == "3" ]]; then
    NOTARY_AUTH_ARGS=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
else
    printf '\nNotarization credentials were not supplied, so no release ZIP was created.\n' >&2
    printf 'Store a validated Keychain profile with this single interactive command:\n' >&2
    printf 'DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun notarytool store-credentials "kltimage-release"\n' >&2
    printf 'At its secure prompts, use the Apple ID, app-specific password, and Team ID %s.\n' "$EXPECTED_TEAM" >&2
    printf 'Then rerun: %s --notary-profile kltimage-release\n' "$0" >&2
    printf 'Signed candidate retained at: %s\n' "$APP" >&2
    exit 2
fi

# Validate the selected credential mode without reading or exposing private credential material.
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun notarytool history \
    "${NOTARY_AUTH_ARGS[@]}" \
    --output-format json >/dev/null || fail "notary credentials are unavailable or invalid"

# This transport archive exists only to submit the unstapled app to Apple. It is never a release artifact.
ditto -c -k --keepParent "$APP" "$NOTARY_UPLOAD"
if ! DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun notarytool submit "$NOTARY_UPLOAD" \
    "${NOTARY_AUTH_ARGS[@]}" \
    --wait \
    --timeout 30m \
    --output-format json >"$NOTARY_RESULT"; then
    fail "notary submission failed"
fi

readonly NOTARY_STATUS="$(plutil -extract status raw "$NOTARY_RESULT" 2>/dev/null || true)"
readonly NOTARY_ID="$(plutil -extract id raw "$NOTARY_RESULT" 2>/dev/null || true)"
[[ "$NOTARY_STATUS" == "Accepted" ]] || fail "Apple notarization was not accepted (submission ${NOTARY_ID:-unknown}, status ${NOTARY_STATUS:-unknown})"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun stapler staple "$APP"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun stapler validate "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
assert_signature_metadata "$FRAMEWORK" "$EXPECTED_FRAMEWORK_IDENTIFIER" "KLTCore.framework"
assert_signature_metadata "$APP" "$EXPECTED_APP_IDENTIFIER" "KLT Image.app"

# The independently verified package remains unmistakably pending until every release gate passes.
ditto -c -k --keepParent "$APP" "$PENDING_ARCHIVE"
readonly FINAL_SHA256="$(shasum -a 256 "$PENDING_ARCHIVE" | awk '{print $1}')"
printf '%s  %s\n' "$FINAL_SHA256" "$(basename "$PENDING_ARCHIVE")" >"$PENDING_CHECKSUM"
if ! (
    cd "$RELEASE_ROOT"
    shasum -a 256 -c "$(basename "$PENDING_CHECKSUM")"
); then
    fail "pending archive checksum self-check failed"
fi

verify_and_promote_or_fail "$PENDING_ARCHIVE" "$PENDING_CHECKSUM" "$FINAL_ARCHIVE" "$CHECKSUM_FILE" "$FINAL_SHA256"

printf '\nRelease candidate ready (not published):\n'
printf '  Archive: %s\n' "$FINAL_ARCHIVE"
printf '  Checksum: %s\n' "$CHECKSUM_FILE"
printf '  SHA-256: %s\n' "$FINAL_SHA256"
printf '  Notary submission: %s\n' "$NOTARY_ID"
