## Using Reproducible Analysis

Download KLT Image 1.2.0 build 5 from [GitHub Releases](https://github.com/dtgibson/kltimage/releases/download/v1.2.0/KLT-Image-1.2.0-build-5.zip) or, from the project's tailnet, the [private Tailscale mirror](https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-preview/releases/KLT-Image-1.2.0-build-5.zip). The SHA-256 for either identical ZIP is `66883ef34f22043bbf74b51e76648ad62527ac47be6fb9c28f33fee2e89ae3aa`.

Unzip it and double-click **KLT Image**. The universal app runs on Apple silicon and Intel Macs without Xcode and passes Gatekeeper normally without removing quarantine or using a security bypass.

To run from source instead, open `KLTImage.xcodeproj` in Xcode 26 or later, select the **KLTImage** scheme and **My Mac**, then press Command-R.

1. Click **Open Image** and choose a JPEG, PNG, TIFF, or HEIC photograph up to 64 megapixels. The image stays on your Mac. Wait until the status says **Result ready**.

2. At the lower right, find **ANALYSIS RECORD · CURRENT** and click **Analysis Record**. The popover opens without replacing the Original, Split, or Enhanced comparison.

3. Start on **Summary**. Check the decoded filename and dimensions, full SHA-256 fingerprint, active color space and matrix mode, statistics source, channel order, units, and exploratory-use notice.

4. Open **Matrices** to inspect the channel mean, covariance, analyzed covariance-or-correlation matrix, descending eigenvalues, deterministic column eigenvectors, and stable counts. Open **Applied transform** to inspect the exact row-major transform, formula, output mapping, and version-1 record-integrity rules.

5. Click **Export JSON**. The Mac save panel suggests `<source-name>-klt.klt-analysis.json`; choose a location and save. The record is written only where you choose and contains no file-system path, timestamp, or processing UUID.

6. Change Color space, Matrix mode, Statistical sample, or committed region bounds. The current record action and both export paths become unavailable immediately, then return after the newly matching result completes.

7. For a region record, choose **Selected region**, draw a rectangle or enter exact X, Y, Width, and Height values, and click **Apply bounds**. Reopen the record after processing and confirm Summary shows both normalized geometry and exact top-left, half-open source-pixel bounds.

8. Dismiss the popover and continue using Original, Split, and Enhanced, synchronized zoom and pan, region editing, and **Export Result** as before. PNG and TIFF preserve transparency; JPEG places transparent areas on white.

9. To run the automated verification from source, press Command-U in Xcode. The suite checks fingerprints, record contents, finite numerical values, eigensystem conventions, the canonical JSON schema and golden bytes, deterministic atomic writes, stale-result behavior, existing image processing, and the interface.

What to look for: the record must always describe the exact displayed result, the fingerprint must be a complete lowercase SHA-256, matrices must stay labeled with their order and units, repeated exports of one record must be byte-identical, and no record may remain available while a replacement request is unfinished or invalid.

Current source verification passes the complete Debug and Release suites: 43/43 Debug tests and 44/44 Release tests, with every acceptance criterion covered. Every 24-megapixel analysis combination remains under five seconds and record generation adds 1.687% median overhead. Full Keyboard Access was disabled during automation, so keyboard coverage combines UI XCTest with live accessibility-tree verification.

## Preparing a trusted macOS release

The 1.2.0 build 5 release uses the same fail-closed release process as the previous trusted build. It requires the installed `Developer ID Application: DAVID THOMAS GIBSON (8QKC3L2FKP)` identity and a validated notarytool Keychain profile. Store the profile once; the command prompts securely for the app-specific password instead of placing it in shell history:

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
./scripts/verify-macos-release.sh /path/to/KLT-Image-1.2.0-build-5.zip EXPECTED_SHA256
```

This verification never removes quarantine. Publishing remains a separate, explicitly approved deployment step.
