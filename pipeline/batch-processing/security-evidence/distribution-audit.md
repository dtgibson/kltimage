# Independent distribution audit

**2026-10-03 — PASS for the retained local candidates.** No publication, upload or installation acceptance is implied.

| Candidate | Independently computed SHA-256 |
|---|---|
| Mac `releases/KLT-Image-1.4.0-build-10.zip` | `a67fc50bdd60fd2ea8ba4621316a67f51a42cd475d23616ca4d34b69d42206d4` |
| iOS `.derived-data/batch-release/KLTImageIOS-1.1-3-TestFlight-export/KLT Image.ipa` | `c43064e35815481ffe521b173e764de585edc6ec8873e00d9563d322d4525a4b` |

Both match the handed candidates; the Mac checksum sidecar also matches. Package hashes were unchanged after verification.

## Mac 1.4.0 (10)

Ran `scripts/verify-macos-release.sh` against the retained ZIP with the separately computed SHA-256. **Exit 0:** app and embedded framework pass strict signatures, both contain exactly arm64 and x86_64, and the expected bundle/version/build, Developer ID identity/team, secure timestamps and hardened runtime pass. The app has exactly the established sandbox and user-selected read/write entitlements; no `get-task-allow`; the framework has no entitlements. The stapled ticket validates, and an independently extracted, quarantined copy passes Gatekeeper as **Notarized Developer ID**.

Compared both release scripts against base `383756798707e651e5363a5babfdd20c5ecabdbb` and mechanically confirmed that only the pinned `1.3.3 (9)` → `1.4.0 (10)` values and verifier usage filename changed. No trust logic changed. The existing expected identity remains `Developer ID Application: DAVID THOMAS GIBSON (8QKC3L2FKP)`.

## iOS 1.1 (3)

Freshly extracted the retained IPA into a disposable audit directory, independently of the Deployer's inspection copy. The app and embedded framework pass strict signature verification; the app also passes deep strict verification. Both are signed by **Apple Distribution: DAVID THOMAS GIBSON (8QKC3L2FKP)** with the expected team and identifiers `com.kltimage.ios` / `com.kltimage.ios.core`, and both are **arm64**. This expectation comes from the existing team/release records and App Store export configuration, not a new identity choice.

App metadata is **1.1 (3)**, minimum iOS **18.0**, device families **[1, 2]**. Framework marketing version is **1.1**. Archive metadata agrees with the IPA. Effective app entitlements contain the correct application/team identifiers, `beta-reports-active=true` and **`get-task-allow=false`**, with no additional keys; framework entitlements are empty.

The embedded profile matches the intended team/app, has `get-task-allow=false`, `beta-reports-active=true`, no device list and no all-devices grant, and expires **2027-07-05**. This is consistent with the explicit **app-store-connect / Apple Distribution** export, not development or ad hoc distribution. The profile was decoded only in memory; no certificate/profile payload was persisted or printed.

## Test controls and evidence

Byte scans of all four retained distribution executables (Mac/iOS app and framework) found no `BatchTestFaults`, `testFaults`, `BATCH_QA_MEMORY`, full-resolution memory-test method or `KLT_UI_TEST` identifiers. Their independent executable hashes agree with the Deployer's local verification record.

- `distribution-audit.json`: package hashes, script comparison, iOS signatures, architectures, metadata, limited profile summary and effective entitlements.
- `distribution-audit.py`: reproducible independent package checks; writes only audit evidence and uses disposable extraction directories.
- `distribution-mac-verifier.log`: complete independent Mac verifier output.
- `distribution-mac-markers.json`: direct ZIP-member executable hashes and test-control scan results.

**Limits remain unchanged:** SEC-I1 and the QA gaps concerning actual providers, external crash windows, native cancellation timing and Mac UI/lifecycle/accessibility remain open as documented. Apple remote validation belongs to the Deployer; this audit made no remote-validation, TestFlight availability, installation or device-behavior claim. No physical device was enumerated/accessed, no native app launched, and no source, release package, release filename, global setting, preview route, unrelated process or pipeline state was changed.
