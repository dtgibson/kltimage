# Schema — Batch Processing

## Path

Incremental. Extend the shipped Mac/iPhone/iPad contracts from `pipeline/ios-app/schema.md` and `pipeline/custom-color-spaces-and-reusable-transforms/schema.md`. Path and routine decisions are authorized by the run's Autopilot instruction. This design follows the approved PRD including its October 3 cleanup clarification. No database, backend, document migration, or scientific change is required.

## Current Schema State

### Existing contracts retained

`KLTCore` remains the scientific and portable-document authority. `DecodedImage` is the first frame, oriented, full-resolution, 8-bit premultiplied-sRGB RGBA source. Its SHA-256 fingerprint uses the existing `KLTImage.AnalysisSource.v1\0` domain, oriented dimensions, and decoded bytes; filenames are descriptive. The source buffer never changes. Existing covariance/correlation, RGB/Lab/affine arithmetic, stability/fallback behavior, alpha, frozen output mapping, and quantization remain unchanged.

`CalculatedAnalysisRequest` contains working-space selection, matrix mode, sample source, and optional source-pixel region. `EnhancementExecutionRequest` is calculated or replayed. `WorkingSpaceRevision` includes identity/kind, definition version, base/conventions, channel names, forward matrix, offset, inverse, and output behavior. Standard RGB/Lab and the three curated spaces remain compiled definitions; user revisions remain validated values. Existing coefficient, inverse, condition, finite-value, and identity limits remain binding. `TransformRecipeSnapshot` captures its identifier/version, algorithm, working-space definition/name, origin, originating analysis, center, transform, and output mapping. Replay does not refit target statistics or apply an origin region to the target.

Each platform retains its independent Application Support method library. `org.kltimage.method-library` v1 holds only `userWorkingSpaces[]` and `savedTransforms[]`, their library names/purpose where applicable, timestamps, and full definition/recipe snapshots. Whole-store validation, the 16 MiB read boundary, unique identities/normalized names, and fsync-backed atomic replacement remain unchanged. Renames affect metadata; mathematical working-space edits advance definition versions; captured recipes remain frozen.

Portable method documents remain `org.kltimage.working-space` v1 and `org.kltimage.transform-recipe` v1. Their 256 KiB import boundary, duplicate-key/depth checks, exact-field/version validation, and rejection of analysis documents remain unchanged. Documentary `org.kltimage.analysis-record` v1 describes standard RGB/Lab calculations; v2 describes nonstandard calculations and every replay. V2 retains separate target/origin, exactly one calculation/replay payload, and per-target replay diagnostics. `AnalysisRecordRouter` and `AnalysisRecordSnapshotJSONEncoder` retain canonical sorted-key finite UTF-8 encoding, explicit nulls, and a trailing newline. No batch fields, paths, timestamps, or output names enter these documents.

The interactive workspace continues to own its source generation, immutable execution request, processing job, and one accepted pixels/record completion. Its replacement-import, comparison, region, zoom, pan, and export contracts are unchanged. No images, interactive state, batch queue, outcome history, or bookmarks persist. The sole new persisted information is the narrowly bounded temporary-file housekeeping receipt below; it grants no external access.

### Ownership after this feature

| Owner | Responsibility |
| --- | --- |
| `KLTCore` | Existing processing and codecs; additive bounded streaming image encoder using identical format options. No picker or batch-run state. |
| Shared app sources, compiled into both app targets | Batch values, one run controller/worker, source staging, temporary budget/receipt, exclusive publication and outcomes. Foundation/Darwin only. No new framework needed. |
| Mac app | Native multi-file/folder panels, workspace exclusion, batch presentation, close/quit handling. |
| iOS app | Native Files/Photos adapters, folder picker, workspace exclusion, foreground lifecycle and batch presentation. |
| User-selected run folder | Committed output plus disclosed, temporary publication files while a write is underway or cleanup is pending. |

## Changes in This Feature

### Added: small transient model

Names are implementation guidance, not a new serialized protocol.

| Value | Fields and invariant |
| --- | --- |
| `BatchInputEntry` | Stable UUID, bounded source display name, opaque platform handle ID, optional selection error. No bytes/thumbnails. At most 100. Repeated picks get distinct IDs. |
| `BatchSetup` | Ordered entries; calculated selection or saved recipe selection; PNG/TIFF/JPEG; JSON flag; transient destination grant. Defaults are RGB/covariance/whole image, PNG, JSON off. |
| `BatchRunRequest` | Fresh run UUID; ordered `(itemID, ordinal, displayName, handleID)` values; full `EnhancementExecutionRequest`; captured method name; format; JSON flag; fixed platform limits; destination lease; proposed unique run-folder component. Immutable after Start. |
| `BatchItemIdentity` | Run UUID, item UUID, fresh source-generation UUID, decoded fingerprint, full request, processing-job UUID. |
| `BatchItemCompletion` | Identity above plus exactly one enhanced image, warning/diagnostics, and matching `AnalysisRecordSnapshot`. Active item only. |
| `BatchItemOutcome` | Identity/ordinal/name, terminal status, bounded reason/warning, actual committed image/JSON filenames. No pixels, encoded bytes, source URL, or record payload. |
| `BatchRunState` | Setup, preparing destination, running(acquiring/processing/saving), stopping(reason), finished(summary). One active item, one terminal outcome per input. |
| `BatchCommitReceipt` | In-memory proof of each completed exclusive rename, final name, and owned-file identity; updated inside the write operation even if cancellation follows. Never serialize as history. |

Source/provider objects live in a platform registry owned by the current batch surface. The immutable run captures retained handle references; removal/canceled selection releases unused handles. Do not pretend `NSItemProvider` or a mutable registry is Sendable: isolate its callbacks behind one adapter and a lock-protected cancellation/completion bridge. Selection generations reject stale picker callbacks and whole additions above remaining capacity without mutating the existing list.

### Run execution and workspace exclusion

Use one shared batch controller with a serial worker, not a scheduler or parallel task group. The main actor owns observable UI state; decode, computation, encoding, counted copies, coordination, and filesystem work run off it. A short synchronized stop flag/publication authorization protects worker boundaries. Do not perform blocking file coordination on the main actor or rely on actor reentrancy to serialize commits.

Acquire a process-wide interactive-workspace exclusion lease before the batch surface becomes usable. If import/analysis/export is active, wait for it to finish or for the user's existing Cancel action; never silently invalidate it. All interactive execution entry points, including menu commands, drop/import routes, automatic control recalculation, and export callbacks, honor the same lease. Preserve the accepted workspace in place. Only one batch surface/run is active. Release the lease after draining work on dismissal, not immediately when a task receives cancellation.

On Start, validate 1–100 entries, at least one apparently eligible input, resolved valid method, destination, no picker operation, and available temporary quota. Construct a calculated request with `.wholeImage` and `region: nil`, or copy the selected complete recipe. Capture names as well as mathematical values. Never call workspace setters to execute a batch.

For each entry: acquire one stable source → decode → build one accepted completion through the existing `ImagePipeline.enhance` or `ImagePipeline.replay` and `AnalysisRecordRouter` → encode requested artifacts → commit image then optional JSON → settle outcome → release all item resources → acquire next. Use an explicit item scope/autorelease pool and await cleanup. Keep no completion or image in outcome rows.

One predicate authorizes completion acceptance and each new artifact commit: active run/item/source generation/fingerprint/job match, full immutable request matches through `RequestAcceptanceGate`, and the run still allows new work. A stop revokes new-work authorization. An operation already admitted to commit must still return its commit receipt after stop; never discard that evidence as a stale result. Later runs cannot start until the previous worker/provider request has drained.

### Lazy intake and stable source

Mac uses `NSOpenPanel` with supported content types and multiple file selection. Mobile Files uses `UIDocumentPickerViewController(forOpeningContentTypes: ..., asCopy: false)` with multiple selection. Mobile Photos uses `PHPickerConfiguration` with `.images`, `.current`, ordered selection, and remaining capacity; retain each result's item provider without calling `loadFileRepresentation` during setup. At most one provider request is active, begun only when its entry reaches the head of the run.

For Photos, request a complete supported file representation, retain/cancel the returned `Progress`, and copy within its completion handler: Apple's temporary URL expires when that handler returns. Never retain that URL for later or use UIImage/thumbnail representations. Callback ownership survives picker dismissal; cancellation of the batch, not ordinary picker dismissal, controls acquisition. A late callback either hands off a fully owned stage to the matching run or cleans it and completes drainage. Do not issue another acquisition while an old callback still owns a file/request.

For Files, begin source security scope only for the active acquisition, perform a coordinated read, and close it after staging. Use the coordinator-provided URL. An app-container URL need not return true from `startAccessingSecurityScopedResource`; distinguish owned URLs from external URLs and fail unauthorized external access. Destination scope is independently owned. Never save bookmarks.

Generalize the counted-copy pattern in `IOSImageSourceStaging` into shared batch code; do not change its interactive limits. Open one descriptor with no-follow/nonblocking flags, require a regular file via `fstat`, reject links/directories/special files, and count bytes in bounded chunks, checking cancellation before each read/write. Compare descriptor identity, size, mtime/ctime before/after, total copied bytes, and path identity while coordinated; changed/replaced sources fail. Do not trust metadata size as the only bound. Decode only the app-owned stable file. Existing ImageIO metadata/orientation preflight and decoded-dimension recheck enforce the platform cap. The same `DecodedImage` supplies result pixels and record fingerprint.

Source contents are captured when that entry is acquired, not when selected. After full decode into owned pixels, remove the encoded source stage before output encoding; a failed removal stays counted and stops further acquisition. Provider-owned originals are never deleted. Names are descriptive bounded basenames (maximum 255 Unicode scalars with invalid control/path characters removed), never executable paths or authorization tokens.

### Resource policy and bounded encoding

| Limit | Mac | iPhone/iPad |
| --- | --- | --- |
| Entries | 100 | 100 |
| Oriented pixels | 64,000,000 | 26,000,000 |
| Counted source bytes | 1 GiB, batch only | 256 MiB |
| Encoded image bytes | 512 MiB | 256 MiB |
| Encoded record bytes | 1 MiB | 1 MiB |
| All app-owned batch temporary bytes, including destination stages/debt | 2 GiB | 768 MiB |
| Known-capacity reserve | 64 MiB | 64 MiB |

Do not use the current unbounded `NSMutableData` image encoder and check its size afterward. Add a file/sink overload using `CGImageDestinationCreateWithDataConsumer`; the consumer counts before writing, refuses over-limit bytes, and checks the run's cancellation token. Return the original typed cap/cancellation/write error even if ImageIO later reports generic finalization failure. Match the current orientation-1 properties, PNG/TIFF alpha, JPEG opaque flattening and quality 0.94 exactly; share format preparation/options with the existing encoder without changing its public behavior. No mathematical or resolution fallback.

Encode one image to a private app-container temporary file; encode JSON using the unchanged canonical encoder and reject above 1 MiB. These are the actual pending bytes for capacity checks. Copy the completed files through counted streams into temporary siblings in the run folder; exclusive rename publishes them. With source stage already removed, worst mobile transient output storage is two 256 MiB image files plus two 1 MiB records, 514 MiB; Mac is 1,026 MiB. Reserve space for all copies and existing cleanup debt before creating them. Account in-progress bytes, not only completed files. Release private encoded files immediately after destination settlement.

The controller owns one budget for the app process. Per-artifact cap/invalid-content failures are item-specific; exhausted aggregate budget, disk space, or cleanup failure is a shared stop. Check exposed destination capacity at Start and before staging/committing each item against actual pending bytes plus 64 MiB, conservatively checking again before publication. Unknown capacity remains unknown and actual write errors control the result. Staging is temporary, never a second local batch of outputs. Platform/ImageIO/provider internals outside app ownership cannot be claimed to satisfy a hard memory/storage cap; app-owned buffers/files do.

### Destination grant and exclusive publication

Mac chooses a directory with `NSOpenPanel`. Mobile uses a native `.folder` document picker in open-in-place mode, one selection. Apple explicitly supports directory access on iOS 13+, including creating child files; deployment remains iOS 18+. Display the chosen location and proposed run folder, not a promised cloud-sync status. The folder grant lasts through setup/run/outcome review; balance scope calls after drainage/dismissal. A canceled replacement picker preserves the old grant.

At Start, under file coordination, create `KLT Batch <local date-time> <full random ownership UUID>` with an exclusive directory creation primitive (`mkdirat`, no-follow parent descriptor), retrying a fresh name on `EEXIST`. Never use recursive/create-if-missing semantics that adopt a prior folder. Open/retain the created directory identity, and reject changed/symlinked ancestors or a run folder that no longer has its expected identity. No input acquisition occurs before destination setup succeeds.

Perform a tiny, receipted capability probe in this new directory before acquiring inputs: exclusive temporary creation, complete write/flush, exclusive rename to an unused probe name, and an attempted exclusive rename onto a probe sentinel that must fail without changing either file. Remove only owned probe files. Check known volume capabilities where available, but rely on the actual exclusive operation for each commit. Coordination is required for providers; it is not itself a no-overwrite primitive. Unsupported flags/semantics, inability to flush/coordinate, or failed cleanup reject the destination. No fallback to ordinary rename, overwrite, copy-to-final, `.atomic` replacement, app storage, or a share sheet.

Prepare publication files named `KLT temporary-<owner UUID>-<file UUID>.part` inside the selected run folder. They are disclosed temporary output, subject to the selected provider. Create mode 0600/exclusive/no-follow and fully copy/flush/close before publication. Use same-directory `renameatx_np(..., RENAME_EXCL)` for the final name; `EEXIST` never replaces an existing file. Anchor descriptor-relative operations to the verified folder and never follow destination links. Use fresh per-operation `NSFileCoordinator` instances on their worker thread, coordinated move/write intents and move notifications as required; use accessor URLs and preserve provider errors. Ordinary `MethodFileIO.durableAtomicWrite` intentionally replaces files and therefore is **not** the batch final-file writer.

Generate `001-<safe source stem>-klt.png` and optional matching `001-<safe source stem>-klt-analysis.json`. Freeze ordinal 001–100 at Start. Normalize/remove separators, controls and path-navigation components; fall back to `image`; truncate by UTF-8 bytes without splitting characters and budget for suffix/extension using the destination's filename limit (conservative 120-byte complete names when unknown). The final basename is always one component. Preflight both requested names; on conflict choose a shared random suffix and try again. Final exclusive rename remains authoritative against races.

The image publishes first. If JSON collides after image publication, retain the complete image and, within the serialized coordinated save, exclusively move that owned image to the new paired suffix before attempting JSON there. This changes its filename, never deletes its content or overwrites another file. Verify ownership before moving; update the in-memory receipt immediately after each successful move. A cancellation or real failure here reports the last actual image name as partially saved. Check stop before starting each move/JSON commit. Bounded conflict retries that repeatedly encounter external mutation may stop as destination contention; ordinary collisions select another suffix. Never publish JSON first, reserve final names with zero-byte placeholders, or delete an image to simulate rollback.

The successful exclusive rename is the artifact's commit boundary. Record it inside the accessor before doing more work. A later cancellation, coordination error, or flush/cleanup failure cannot erase that fact; retain/report the committed image and stop according to the actual requested-artifact state. Each final file contains complete encoded bytes. There is no two-file transaction or promise of provider cloud synchronization. Third-party providers that cannot meet local publication semantics are visibly unsupported; universal provider success is not a requirement.

### Cleanup ownership and minimal persisted receipt

Private staging lives in an app-owned, mode-0700, backup-excluded batch temporary root. Use only randomized owned filenames and no-follow operations. Launch cleanup is limited to that root's verified owned temporary files; do not sweep arbitrary system temp files or user folders.

Persist external temporary reservations **before** their creation in a private, backup-excluded Application Support housekeeping receipt. Its internal version-1 shape is a bounded array of `{ownerToken: UUID, temporaryBasename: String, reservedBytes: UInt64}` under a schema/version envelope. These are the only per-file fields: no paths, source identifiers/names, method, final-output names, queue, or run outcomes. Basenames must match the exact random temporary grammar and token; enforce unique entries, checked arithmetic, nonnegative bounded reservations, a 256-entry/256 KiB receipt limit, and fail closed on corruption/future versions. Reuse the durable private-file replacement primitive with mode 0600. Do not modify the method-library file.

Reserve a conservative upper bound before writing, shrink to verified size afterward, and clear only after successful owned unlink or successful rename out of the temporary name. Crash windows may overcount but never undercount. If receipt updates fail, stop new work. Its tokens are not access grants. No receipt means no claim to external files. A launch reads unresolved debt before enabling Start; it does not reopen or summarize a batch.

While the grant is live, clean exact known temporary names under the verified run-directory identity. After grant loss/relaunch, offer explicit selection of the associated run folder. Match its full ownership UUID suffix to the receipt and reject unrelated folders; inspect only receipted direct-child names, never recursively scan. Check names, regular-file/no-symlink status and byte bounds before removal; mismatches remain untouched with debt retained. Verify absence in the matching selected folder before clearing a missing temporary reservation. Cancel/wrong-folder selection leaves debt intact. External edits that remove/rename the identifying run-folder suffix can prevent automatic recognition; never guess another folder or waive debt to proceed. Clear receipt entries after cleanup; no durable history remains.

Remove a failed-start run folder only with the still-valid grant, verified created identity, and atomic empty-directory removal. Never recursively delete it. Successful final files and unrelated sentinels survive cleanup.

### Stopping and outcome accounting

Cancel immediately sets stopping and revokes admission to acquisition/processing/new commits; acknowledge on the main actor within one second. Forward cancellation to the worker, file coordinator and provider `Progress`, but wait for already-running callbacks/commits and cleanup before settling or releasing scope. A native noninterruptible operation may finish. Never infer commit status solely from `Task.isCancelled` or an exception caught after rename.

| Active item's actual artifacts | Cancel/interruption result |
| --- | --- |
| None | Canceled; no JSON is published. |
| Image only, JSON requested | Partially saved, image name shown and missing record explicit. |
| Every requested artifact | Saved or saved with warning, even if stop arrived immediately afterward. |

Untouched entries are not processed. On an item-specific acquisition/decode/validation/numerical/encoding/record-generation error, fail that item and continue after cleanup. Prepare requested JSON before publishing the image where possible; still handle real JSON write failures after image commit as partial. Permission loss, provider unavailability, shared capacity/budget/cleanup failure stops remaining work. Completed counts are derived from settled rows; successful includes warning-success and excludes partial. Only all-success reports “Batch complete”; distinguish finished-with-errors, canceled, interrupted, and destination stop.

On iOS, `.background` initiates interrupted stop; `.inactive` alone does not. A finite UIKit background task may be used only to drain/cancel the current operation and clean up, never start another item or promise completion. Expiration revokes work and leaves receipts conservative. Return to foreground shows the stopped outcome; termination restores no queue/outcome. On Mac, focus changes do nothing; close/quit initiates the same stop and delays release of the controller until drainage where the OS permits. Forced termination uses next-launch private cleanup and unresolved external debt.

Return to setup retains only the current surface's handles/list/choices, discards prior completion data, and requires a new explicit Start with fresh IDs, method validation, and run folder. Dismissal releases handles and resets defaults on reopening. Existing committed outputs are never reopened for mutation.

### Modified / unchanged

Additive changes: a bounded streaming encoder overload; app-source references in `project.yml`; native batch entry/presentation; shared execution exclusion guards. Existing encoder APIs and interactive source limits remain supported. Regenerate the Xcode project after source-list changes. No production store/document fields, mathematical algorithms, golden JSON, signing requirements, release channels, or physical-device policy change.

## Migration / Implementation Plan

1. Add shared batch values/controller and a minimal source/destination adapter boundary. Compile shared app files into Mac and iOS targets without introducing a framework or refactoring unrelated workspace code.
2. Add counted staging, bounded ImageIO consumer encoding, private quota receipt, and coordinated exclusive publisher. Establish fault-injection tests before wiring real picker/UI callbacks.
3. Connect native lazy inputs/folder selection, immutable method snapshots and existing core calls. Add workspace lease guards and lifecycle drainage.
4. Add the dedicated adaptive batch surface against these states, then run PRD QA and existing platform regressions. No migration of existing library bytes and no first-launch batch state creation unless temporary reservations are needed.

Suggested boundaries: `SharedBatch/BatchModel.swift` for values/controller; `SharedBatch/BatchFileIO.swift` for staging, budget/receipt and publication; platform `BatchSources`/`BatchView` files for native adapters/presentation; `KLTCore/ImagePipeline.swift` for the bounded encoder. Split only when implementation size warrants it. Keep cancellation and outcome logic shared rather than implementing two independent runners.

## Feasibility and Verification

See `architecture-evidence/feasibility.md` and `architecture-evidence/NativeBatchAPIs.swift`. Native iOS directory selection and exclusive-rename API availability are established. The local exclusive-rename probe passed; the API probe typechecked for arm64 iOS 18 Simulator. This is not provider runtime acceptance, simulator UI testing, or TestFlight verification.

Implementation evidence must cover PRD QA-01–26, especially: exact pre-encoding parity for both modes and unchanged golden JSON; bounded 100-item intake with one provider request; growing/changed/nonregular sources; bounded encoder aborts; collisions before image and between image/JSON; stop before/during/after each commit; cancellation of late Photos callbacks; unknown/low capacity; receipt crash windows and repeated relaunch; wrong-folder cleanup and unrelated sentinels; foreground/background differences; restored interactive identity/geometry; and full-resolution memory independent of settled count. Use deterministic injected provider/file-operation seams plus local filesystem tests. Real provider behavior unavailable in the simulator stays explicitly unverified and fails closed at runtime.

Run Mac Debug/Release and relevant local iPhone/iPad simulator suites; preserve the Release 24 MP benchmark below five seconds. Never enumerate or access physical devices. Mac retains its signed/notarized GitHub release path; iOS ships through TestFlight. Any visual review handoff must be separately served and verified over tailnet-only HTTPS; this architecture adds no preview service.

## Design Decisions

- Reuse the existing core requests and records; batch is bounded app orchestration, not another scientific pipeline.
- Use a fresh user-visible folder per explicit run and exclusive per-file publication. Successful images survive later record failure.
- Separate transient run state from minimal cleanup debt. External temporary cleanup after lost access requires user reselect; it cannot be promised automatically without forbidden persistent grants.
- Native provider support is conditional on required coordinated filesystem operations. A picker grant alone is not proof that a provider supports safe publication.
