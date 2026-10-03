# Native batch-file feasibility

Checked 2026-10-03 on this development Mac. No device enumeration or physical-device access occurred.

## Native folder access

Apple's [Providing access to directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories) states that iOS 13+ document pickers can select a directory from available file providers, return a security-scoped URL, and permit adding/modifying child files. It shows `UIDocumentPickerViewController(forOpeningContentTypes: [.folder])`, requires balanced security-scope access and coordinated reads/writes, and warns that permission can be revoked. It does not guarantee each provider supports every filesystem operation. The app will not use the optional bookmark mechanism.

Apple's [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator) documents per-operation, single-thread coordinator use and automatic background time for granted coordinated access. Coordination notifies interested presenters; it does not supply an exclusive no-overwrite filesystem commit.

Apple's [loadFileRepresentation](https://developer.apple.com/documentation/foundation/nsitemprovider/loadfilerepresentation(fortypeidentifier:completionhandler:)) states that its temporary file is deleted when the completion handler returns. Batch must copy within that callback and defer the request until the item's turn.

These Apple pages were retrieved as their public DocC JSON on the check date. No private account or remote device was accessed.

## SDK and local proof

The installed iPhoneSimulator SDK's `usr/include/sys/stdio.h` declares `renameatx_np` available on iOS 10.0+ and defines `RENAME_EXCL`. Its `sys/attr.h` defines `VOL_CAP_INT_RENAME_EXCL` as volume support for exclusive rename. UIKit headers expose open-in-place content-type document pickers.

`NativeBatchAPIs.swift` is architecture-only probe code, not product source. Commands run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift -swift-version 6 pipeline/batch-processing/architecture-evidence/NativeBatchAPIs.swift
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun --sdk iphonesimulator swiftc -swift-version 6 -typecheck -target arm64-apple-ios18.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk pipeline/batch-processing/architecture-evidence/NativeBatchAPIs.swift
```

Both exited 0. Local probe output:

```text
PASS: exclusive rename rejects an existing destination, preserves both files, and publishes complete bytes at an unused name.
Scope: this Mac's temporary filesystem only; no provider, simulator runtime, or physical device exercised.
```

The iOS compile check includes the `.folder` picker, `renameatx_np(..., RENAME_EXCL)`, and `CGImageDestinationCreateWithDataConsumer`. It establishes API availability, not provider runtime behavior. Native provider capability checks, cancellation/error paths, coordinated moves, and paired-name collision recovery still require implementation tests. Providers without the required semantics must be rejected; generic copy/overwrite is not a fallback.

## Cleanup feasibility correction

Same-destination publication staging is necessary when a destination is on another volume/provider. If the process dies, an app without persisted permissions cannot silently clean those external files next launch. The approved PRD now distinguishes automatic app-container cleanup from external cleanup under the current grant or explicit run-folder reselect, with anonymous ownership/quota receipts and no restored queue/history. See `../decisions.md` and FR-27/NFR-05/QA-23.
