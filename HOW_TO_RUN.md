## Using Custom Color Spaces and Reusable Transforms

KLT Image 1.3.1 build 7 is available from [GitHub Releases](https://github.com/dtgibson/kltimage/releases/tag/v1.3.1). Its SHA-256 is `620044cc2191ee15c229d0abbdb0839eae703852081b1a179782e7942f10a0a1`. GitHub is the canonical release channel. To run from source, open `KLTImage.xcodeproj` in Xcode 26 or later, select the **KLTImage** scheme and **My Mac**, then press Command-R.

1. Click **Open Image** and choose a JPEG, PNG, TIFF, or HEIC photograph up to 64 megapixels. Wait for **Result ready**. Images, methods, filenames, and fingerprints remain local to the Mac.

2. Use the comparison picker to move among **Original**, **Side-by-Side**, **Slider**, and **Processed**. Zoom and pan remain synchronized. Drag the Slider divider, or focus it and use arrows, Shift-arrows, Home, and End.

3. Open **Methods**. The library separates working spaces, which calculate a new transform, from saved transforms, which replay frozen values unchanged. Inspect the two standard spaces and the three documented curated spaces.

4. Apply a curated space such as **Luma + Chroma**, then switch covariance/correlation or whole-image/selected-region sampling. Confirm the rail and analysis record label the result **Calculated** and show the active definition identity and version.

5. In **Methods**, choose **New working space** or duplicate a curated definition. Name the three output channels and enter a reversible 3×3 forward matrix plus three offsets over encoded sRGB or CIE Lab D65. Invalid, singular, ill-conditioned, inconsistent, non-finite, or out-of-range definitions remain unsaved with a specific explanation.

6. With a current non-limited calculated result, choose **Save Calculated Transform** and name it. The recipe freezes the accepted working-space revision, source identity, statistical setup, center, transform, and output mapping.

7. Select the saved transform and choose **Apply to Current Image**. Analysis controls become provenance-only because replay does not recalculate target statistics. If clipping or low contrast is observed, use **Calculate for This Image** as an explicit separate action.

8. Export a user working space as `.klt-space.json` or a saved transform as `.klt-transform.json`, then import it through **Methods**. Import validates the complete bounded local file as inert JSON before presenting Add, Replace, Import as Copy, or Cancel. Cancel and every failure leave the library, image, result, and controls unchanged.

9. Open **Analysis Record**. Standard RGB/Lab calculated results retain the byte-compatible version-1 document. Curated/custom calculations and all replays use version 2; replay records nest origin and frozen values under `replay`, set `calculation` to `null`, and contain no target covariance, mean, eigensystem, gains, or sampling region.

10. Press Command-U to run the Debug suite. For the supported optimized verification configuration, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project KLTImage.xcodeproj -scheme KLTImage \
  -configuration ReleaseTests \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derived-data/release-tests \
  -only-testing:KLTCoreTests -only-testing:KLTImageTests
```

`ReleaseTests` encodes arm64 active-architecture testability for local optimized XCTest. It does not change the universal, hardened, non-testable shipping `Release` configuration. The optimized suite measures the existing 24-megapixel analysis matrix, one affine calculation, one frozen replay, and a 500-item library load.

What to look for: calculated and replayed modes must never be ambiguous; saved recipes must replay byte-identically on their origin source; no edit may retroactively alter a saved recipe; comparison mode changes must never alter the scientific result; and rejected imports must make no persistent change.

Final release verification passes 96/96 Debug tests and 98/98 optimized `ReleaseTests`, including all macOS UI workflows and the 24-megapixel optimized performance checks. The keyboard-only workflow preserves an already-enabled Full Keyboard Access setting, creates complete encoded-sRGB and CIE Lab D65 spaces, and finds both rows after process termination and relaunch. The slider-drag and replacement-image regression suites pass, and both security reviews report zero findings.

## Preparing a trusted macOS release

The published 1.3.1 build 7 release uses the same fail-closed process as trusted 1.3.0 build 6. GitHub Releases is the sole production publication target; the previous tailnet mirror is no longer a required final release step. The process requires the installed `Developer ID Application: DAVID THOMAS GIBSON (8QKC3L2FKP)` identity and either a validated notarytool Keychain profile or the existing App Store Connect Team API credential path. Store a profile once; the command prompts securely for the app-specific password instead of placing it in shell history:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun notarytool store-credentials "kltimage-release"
```

At the secure prompts, enter the Developer Apple ID, its app-specific password, and Team ID `8QKC3L2FKP`.

Then create the candidate in a temporary directory:

```sh
./scripts/release-macos.sh --notary-profile kltimage-release
```

The same script also supports an App Store Connect Team API key without reading or printing its contents:

```sh
./scripts/release-macos.sh \
  --notary-key /secure/path/AuthKey_KEYID.p8 \
  --notary-key-id KEYID \
  --notary-issuer ISSUER_UUID
```

The script builds a universal Release app, signs the nested framework before the app, validates the identity, Team ID, timestamps, hardened runtime, version, architectures, and exact entitlements, waits for Apple notarization, and staples and validates the ticket. It creates only unmistakably pending archive/checksum names while an independent verification copy is extracted, quarantined, and required to pass Gatekeeper as `source=Notarized Developer ID`. Only then are both files atomically promoted to final release names. Any failed check stops the release while preserving the staged app and pending diagnostics, with no final-named ZIP.

Exercise that final boundary without building or notarizing:

```sh
./scripts/release-macos.sh --self-test-promotion
```

After copying or downloading an artifact, verify it against its separately recorded SHA-256:

```sh
./scripts/verify-macos-release.sh /path/to/KLT-Image-1.3.1-build-7.zip EXPECTED_SHA256
```

This verification never removes quarantine. A fresh GitHub download of Build 7 matched the approved artifact byte-for-byte and independently passed this verifier. Trusted 1.3.0 build 6 remains the rollback release. Its prior GitHub and tailnet publication and verification remain historical facts; the existing tailnet route and old artifacts are unchanged but are not part of the Build 7 production release.
