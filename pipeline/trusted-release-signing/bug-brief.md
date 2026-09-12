# Bug Brief — Trusted Release Signing

## What is broken
The tailnet ZIP for KLT Image 1.1.0 build 3 is intact but is not a trusted macOS distribution artifact.
Both the app and embedded framework are ad-hoc signed, the app has no TeamIdentifier, and no notarization ticket is stapled.
A freshly downloaded/quarantined copy is therefore rejected by Gatekeeper and can produce macOS's “move to Trash” warning.

## Steps to reproduce
1. Download the tailnet ZIP; it is 1,573,020 bytes with SHA-256 `011ad363f46f9b9d81a6be3aeb936de1f692ed19fcc63e2ad0ba0207c353db7a`.
2. Extract it and apply normal download quarantine to `KLT Image.app`.
3. `codesign --verify --deep --strict` passes internal integrity, but `codesign -dvvv` reports `Signature=adhoc` and `TeamIdentifier=not set`.
4. `xcrun stapler validate` reports no ticket, and `spctl --assess --type execute --verbose=4` reports `rejected`.

## Expected behavior
The exact package offered for download should pass Gatekeeper on a clean Mac without a bypass or removal of quarantine.
It should retain its sandbox/file entitlements, identify the Developer ID publisher, and carry verifiable Apple notarization.

## Root cause and evidence
The byte-identical staged/tailnet release used `CODE_SIGNING_ALLOWED=NO`; packaging then ran `codesign --force --sign - --timestamp=none --options runtime` on the framework and app.
The deploy check explicitly required `flags=.*adhoc,runtime`; its Gatekeeper rejection was observed but was not a release-blocking assertion.
Project guidance and the deployment decision classified ad-hoc/unnotarized signing as acceptable for private/local distribution.
No release script or CI workflow enforces Developer ID signing, notarization, stapling, or Gatekeeper acceptance.
A valid `Developer ID Application: DAVID THOMAS GIBSON (8QKC3L2FKP)` identity exists, so this was process policy, not missing signing capability.

## Prior-release finding
GitHub's v1.0.0 build 2 asset has SHA-256 `5a315c9c860ab9f6bf3ce43153e9ec5f3192766c22b5cf5d8a465910ca1c0dd5`, exactly matching the repository's old ZIP.
That app also reports `Signature=adhoc`, no TeamIdentifier, no stapled ticket, and Gatekeeper rejection; the release note says it was not Developer ID-signed/notarized.
There is therefore no trusted older published artifact to regress from; an older copy likely avoided assessment, lost quarantine, or had a local user exception.

## Trust boundaries
Developer ID signing authenticates the publisher and seals nested code; it does not itself prove Apple notarized the artifact.
Notarization is Apple's malware review, and stapling makes its ticket travel with the app; both must be verified independently.
Quarantine triggers Gatekeeper at first launch, exposing the defect; removing quarantine is a workaround, not a release fix.

## Blast radius
Every fresh Build 3 download is affected on Macs enforcing normal quarantine/Gatekeeper policy; already downloaded copies cannot be recalled.
The same latent packaging defect affects the published v1.0.0 asset, though local/unquarantined builds may still launch.
Product processing code and saved images are not implicated; the scope is packaging, release verification, download links, and signing documentation.

## What done looks like
Produce a new universal release by signing nested code then the app with Developer ID, hardened runtime, secure timestamps, and only the intended sandbox/file entitlements (no `get-task-allow`).
Receive an accepted notarization, staple and validate its ticket, then prove the quarantined exact ZIP downloaded from the tailnet passes strict signature checks and `spctl` as `Notarized Developer ID` and launches normally.
Make those checks fail-closed in a repeatable release process, publish an unambiguous replacement build/checksum, and stop advertising the affected Build 3 package.
