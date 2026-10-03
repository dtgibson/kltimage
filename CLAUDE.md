# KLT Image Project Conventions

## Architecture

- Keep scientific transforms, image-format logic, and versioned document codecs in shared `KLTCore`; keep each platform's SwiftUI, AppKit/UIKit/PhotosUI file workflows, and main-actor workspace state in its app target.
- Preserve the decoded source buffer unchanged. Enhanced results use separate buffers and explicit export destinations.
- Keep image processing local, cancellable, deterministic, and outside the main actor.
- Keep working-space definitions, frozen transform recipes, and documentary analysis records as separate typed artifacts: working spaces calculate, recipes replay captured values, and analysis records are never executable method input.
- Keep each accepted calculated or replayed image and analysis record in one immutable, job-identified snapshot, and gate every inspection or export surface on exact source generation, immutable execution request, and job UUID through one shared predicate; cooperative cancellation alone is not a currency guarantee.
- Treat versioned analysis JSON as a protocol contract: use dedicated export DTOs, canonical sorted-key finite encoding with explicit nulls, atomic writes, and golden-byte compatibility coverage; keep export local, explicit, and free of implicit persistence or network transfer.
- Keep portable method import bounded to a regular file of at most 256 KiB, duplicate-key-aware, exact-field and exact-version validated, and fail-closed before any library or workspace mutation; reject analysis-record schemas at the method boundary.
- Keep persistent user content limited to methods, with no pixels, results, history, regions, bookmarks, queues, or ordinary workspace state. The only batch housekeeping exception is a bounded, backup-excluded receipt containing random ownership tokens, random temporary basenames and byte reservations; it grants no access, restores no run, and requires explicit folder reselect for external cleanup after access is lost. Validate the complete library before publication and use the shared mode-`0600`, fsync-backed, same-directory atomic replacement path for private stores and method-export writes.
- Keep Mac and iOS method stores independent; exchange methods only through explicit compatible documents. On iOS, validate an existing store before its first mutation and count provider-source bytes while staging, with a fixed 256 MiB encoded limit, a 26-million-oriented-pixel decode limit, and cleanup of app-owned staging files.
- Batch output uses exclusive no-overwrite publication, not the replacing method-store writer. Capture each actual commit before later operations can fail; cancellation must reconcile those receipts, preserve committed images, and report requested-but-missing records as partial saves.
- Keep full-frame raster allocations behind the checked ownership helper, with exactly one free on failure or one transfer to Data on success; preserve decoder and scientific byte parity when changing buffer ownership.

## Interface

- Development previews and design reviews must be reachable through HTTPS Tailscale links. The user generally cannot access the development Mac locally; localhost, file URLs, and filesystem links are not usable preview handoffs. Verify the tailnet URL before sharing. This does not change GitHub as the Mac production release channel.

- Follow `pipeline/design-system.md`: a quiet, fixed light scientific palette, IBM Plex typography, restrained teal actions, and content-first layouts.
- Keep zoom percentages relative to Fit: 100% means Fit, and 1000% means ten times Fit, not a fixed display-pixel-to-source-pixel ratio. Buttons and pinch must share the same ceiling on all platforms.
- On iPhone and iPad, keep source, result, and sample geometry registered while touch gestures change only the view; give the slider divider and sample editor separate gesture ownership.
- Native controls placed on the fixed light palette must explicitly use a matching light appearance so macOS dark mode cannot reduce contrast.
- Preserve VoiceOver labels, keyboard access, status announcements, and reduced-motion behavior when changing controls. Mobile actions need actual 44-point hit targets; verify edge taps as well as accessible bounds and text wrapping.
- Keep approved app-icon artwork in its editable SVG master and committed native PNG catalog; after artwork changes, use `scripts/export-app-icon.py --check` to detect divergence and regenerate only from the approved design.

## Project and Verification

- `project.yml` is the source of truth for the generated Xcode project; regenerate `KLTImage.xcodeproj` with XcodeGen after project-setting changes.
- Run both Mac Debug and Release XCTest bundles. The 24-megapixel benchmark, including source-fingerprint and analysis-record overhead, is Release-only and must remain below five seconds on supported Apple silicon. Run iOS tests and UI checks on local simulators.
- Agents must never access any physical device. The user and their testers own all on-device verification through TestFlight; simulator results do not establish TestFlight installation or provider-backed device behavior.
- Treat supported-format import, orientation, alpha preservation, deterministic output, numerical stability, and export dimensions as regression requirements.
- Keep test path and environment overrides inside `#if DEBUG`. Define `DEBUG` for the optimized `ReleaseTests` configuration so XCTest can exercise those hooks, verify their identifying strings are absent from the shipping executable, and never add that condition to the universal hardened non-testable `Release` configuration.
- Treat only signed complete XCTest runs as UI-verification evidence: `CODE_SIGNING_ALLOWED=NO` can invalidate test bundles before app tests begin. Use per-process `DEVELOPER_DIR` for native tooling and preserve global Xcode/accessibility settings, including an already-enabled Full Keyboard Access mode; blocked native automation is not replaced by a unit-test acceptance claim.

## Release Packaging

- Every downloadable build, including a private tailnet build, must use `scripts/release-macos.sh`; ad-hoc signing is not a distributable release path.
- Build a universal Release app and embed an unambiguous marketing version and build number.
- Sign the embedded `KLTCore.framework` before the containing app with the required Developer ID identity, hardened runtime, secure timestamps, and only `KLTImage/KLTImage.entitlements`.
- Notarization acceptance, stapling, ticket validation, and quarantined Gatekeeper acceptance as `Notarized Developer ID` are mandatory before packaging or publication. Never remove quarantine as a workaround.
- Keep the release ZIP and checksum under unmistakably pending names until the independent verifier succeeds. Verification failure may retain pending diagnostics but must leave no final-named artifact; promote final names only with same-volume renames after acceptance.
- Verify the final ZIP with `scripts/verify-macos-release.sh` and a separately recorded SHA-256. Reject unexpected identity/team, architectures, versions, entitlements, or `get-task-allow`.
- After explicit production approval, publish the same versioned, independently verified ZIP and checksum through GitHub Releases as the canonical production channel; re-download and independently verify the served copy before advertising it. Historical mirrors are not a release gate.
- Ship iOS builds separately through signed App Store Connect/TestFlight delivery; verify processing and tester availability before claiming installation or on-device acceptance. The Mac GitHub channel and its release trust requirements remain independent.
