## Using KLT Image locally

If you have access to the project's tailnet, download the private [KLT Image 1.1.0 build 4 package](https://hephaestus-developer.giraffe-chuckwalla.ts.net/kltimage-preview/releases/KLT-Image-1.1.0-build-4.zip). Its SHA-256 is `4e884df54b06c393dbbb48c77bc96477b915dc4ba79cf26c6a29c7f59f672442`.

Unzip it and double-click **KLT Image**. The universal app runs on Apple silicon and Intel Macs without Xcode. It is Developer ID-signed, notarized by Apple, and stapled, so a normally downloaded copy passes Gatekeeper without removing quarantine or using a security bypass. The affected Build 3 package remains hosted only as an unadvertised rollback artifact and should not be used.

To run from source instead, open `KLTImage.xcodeproj` in Xcode 26 or later, select the `KLTImage` scheme and `My Mac`, and press Command-R.

1. Click **Open Image** and choose a JPEG, PNG, TIFF, or HEIC photograph up to 64 megapixels. Processing starts with RGB, Covariance, and Whole image selected, and stays on your Mac. Larger images are rejected before full-resolution decoding with a readable size-limit message.

2. Use **Color space** to compare RGB with CIE Lab D65, and **Matrix mode** to compare covariance with correlation. Each committed choice recalculates the full-resolution result from the unchanged source.

3. Under **Statistical sample**, keep **Whole image** or choose **Selected region**. Draw a rectangle over the source pane, then drag inside it to move it or drag a corner to resize it. You can also enter exact top-left source-pixel X, Y, Width, and Height values and click **Apply bounds**.

4. In region mode, the rectangle supplies the statistics used to derive the transform; the complete image is still enhanced. Invalid bounds remain editable for correction, do not fall back to another sample, and keep export unavailable until a matching result is ready.

5. Use **Original**, **Split**, and **Enhanced** to compare results. Drag the image background to pan, pinch to zoom, use the zoom buttons, or double-click to fit. Split panes share navigation and display the same active region.

6. Click the information button beside the active method to review its variables, matrix basis, statistical sample, stable-component count, and exploratory-use cautions.

7. Click **Export Result**, choose PNG, TIFF, or JPEG in the Mac save panel, and save the current full-resolution enhancement. The selection outline is not exported. PNG and TIFF preserve transparency; JPEG places transparent areas on white.

8. Press Command-U in Xcode to run the numerical, image-format, analysis-control, and interface automation checks.

What to look for: method and sample labels should always describe the displayed result; invalid or superseded requests must keep export disabled; both Split panes should stay aligned; the original must remain unchanged; and exported dimensions must match the source.

## Preparing a trusted macOS release

Build 4 uses a fail-closed release process. It requires the installed `Developer ID Application: DAVID THOMAS GIBSON (8QKC3L2FKP)` identity and a validated notarytool Keychain profile. Store the profile once; the command prompts securely for the app-specific password instead of placing it in shell history:

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
./scripts/verify-macos-release.sh /path/to/KLT-Image-1.1.0-build-4.zip EXPECTED_SHA256
```

This verification never removes quarantine. Publishing remains a separate, explicitly approved deployment step, and the existing private-only QA caveats still apply.
