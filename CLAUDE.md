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

- Build a universal Release app and embed both marketing version and build number.
- For an ad-hoc package, sign the embedded `KLTCore.framework` first, then sign the app with `KLTImage/KLTImage.entitlements`.
- Before publishing a ZIP, verify archive integrity, strict deep code-signature validity, embedded sandbox entitlements, bundle version, build number, and SHA-256 checksum.
- Treat ad-hoc, unnotarized packages as private/local only; broad public distribution requires Developer ID signing, notarization, and a final artifact without `get-task-allow`.
