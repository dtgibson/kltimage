# KLT Image Project Conventions

## Architecture

- Keep scientific transforms and image-format logic in `KLTCore`; keep SwiftUI, AppKit file panels, and main-actor workspace state in `KLTImage`.
- Preserve the decoded source buffer unchanged. Enhanced results use separate buffers and explicit export destinations.
- Keep image processing local, cancellable, deterministic, and outside the main actor.
- Gate displayed and exportable results on exact source, request, and job identity; cooperative cancellation alone is not a currency guarantee.

## Interface

- Follow `pipeline/design-system.md`: a quiet, fixed light scientific palette, IBM Plex typography, restrained teal actions, and content-first layouts.
- Native controls placed on the fixed light palette must explicitly use a matching light appearance so macOS dark mode cannot reduce contrast.
- Preserve VoiceOver labels, keyboard access, status announcements, and reduced-motion behavior when changing controls.

## Project and Verification

- `project.yml` is the source of truth for the generated Xcode project; regenerate `KLTImage.xcodeproj` with XcodeGen after project-setting changes.
- Run both Debug and Release XCTest bundles. The 24-megapixel benchmark is Release-only and must remain below five seconds on supported Apple silicon.
- Treat supported-format import, orientation, alpha preservation, deterministic output, numerical stability, and export dimensions as regression requirements.

## Release Packaging

- Every downloadable build, including a private tailnet build, must use `scripts/release-macos.sh`; ad-hoc signing is not a distributable release path.
- Build a universal Release app and embed an unambiguous marketing version and build number.
- Sign the embedded `KLTCore.framework` before the containing app with the required Developer ID identity, hardened runtime, secure timestamps, and only `KLTImage/KLTImage.entitlements`.
- Notarization acceptance, stapling, ticket validation, and quarantined Gatekeeper acceptance as `Notarized Developer ID` are mandatory before packaging or publication. Never remove quarantine as a workaround.
- Keep the release ZIP and checksum under unmistakably pending names until the independent verifier succeeds. Verification failure may retain pending diagnostics but must leave no final-named artifact; promote final names only with same-volume renames after acceptance.
- Verify the final ZIP with `scripts/verify-macos-release.sh` and a separately recorded SHA-256. Reject unexpected identity/team, architectures, versions, entitlements, or `get-task-allow`.
