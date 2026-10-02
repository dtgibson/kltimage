# Strategic Brief — KLT Image for iPhone and iPad

## What We're Building

Bring KLT Image to iPhone and iPad as a native iOS app alongside the existing Mac app. A user can open a photograph, run the same transparent decorrelation-stretch methods, compare the unchanged source with the result, inspect the analysis, and export the full-resolution result and its record through touch-first workflows.

## Why Now

KLT Image's core method, provenance, and local method library are established on macOS. The user's request to run it on iPhone and iPad expands the original Mac-only platform decision while preserving the product's purpose: exploratory color analysis with the source always available for interpretation. A mobile app makes that workflow useful where photographs are captured and reviewed, without requiring an account, upload, or separate scientific imaging environment.

## The User Problem

A researcher, naturalist, photographer, or technically curious analyst may have a bird photograph on an iPhone or iPad but must move it to a Mac to use KLT Image. They need to examine subtle color structure on the device at hand, select a meaningful source region with touch, and carry an interpretable image and analysis record into their existing workflow. A phone's compact screen and an iPad's larger canvas need different layouts, but neither should hide the unchanged source or change what a saved method means.

## Success Criteria

- The app runs natively on supported iPhone and iPad devices while the macOS app continues to build and behave as before.
- A user can choose a local image from Files or Photos, calculate an enhancement, and compare the original and processed image without altering the source.
- RGB, Lab, the shipped curated and user-defined working spaces, covariance and correlation, whole-image and rectangular-region sampling, and frozen transform replay retain the same mathematical meaning and deterministic output for the same decoded source and method.
- Touch controls make region selection, zoom, pan, and original/result comparison usable on both device sizes; the iPad uses its extra space to keep more analysis context visible.
- A user can inspect whether a result was calculated or replayed, view its source and method provenance, and export the current full-resolution image and deterministic JSON analysis record.
- The local method library supports the shipped create, inspect, edit, duplicate, rename, delete, import, and export actions. Compatible method documents can be moved between Mac and iOS through explicit file exchange without changing their meaning.
- Processing stays off the main interface thread, can be cancelled, and gives a clear response when an image exceeds the device's supported memory or pixel limit. The app does not silently reduce resolution or substitute a different method.
- Files, Photos, exported images, records, and method documents remain local unless the user explicitly chooses a destination or share action. Enhanced color remains labeled as exploratory evidence, not a scientific finding.

## Scope

- A native iOS/iPadOS target and adaptive SwiftUI interface that share the existing tested numerical and image-processing behavior with macOS where technically appropriate.
- Touch-first image import from Files and Photos, analysis controls, rectangular source sampling, comparison, result export, analysis-record inspection and JSON export.
- The existing method library and strict versioned method-document import/export on iOS, with app-local persistence and explicit file exchange.
- iPhone and iPad layouts, accessibility support, and clear processing, cancellation, error, and memory-limit states.
- Cross-platform fixtures and device testing sufficient to verify method parity, image orientation and color handling, alpha, exports, and the current scientific guardrails.
- An iOS distribution and signing path appropriate to the approved release, established separately from the Mac app's GitHub ZIP and Developer ID workflow.

## Out of Scope

- Redesigning the decorrelation-stretch algorithm, changing versioned document semantics, or adding new analysis methods for the mobile release.
- Automatic iCloud or cross-device sync, accounts, a backend, uploads, or a shared image/history library.
- Camera capture inside KLT Image, automated bird or feather segmentation, batch processing, or multi-image projects.
- Raising the existing 64-million-pixel full-frame ceiling or building a tiled/out-of-core processor as part of the port.
- Scientific classification, quantitative conclusions, or claims that an enhanced color proves a biological feature.
- Replacing the macOS app or treating its GitHub release channel as an iOS installation mechanism.

## Key Decisions

- Interpret "alongside macOS" as one product with native interfaces on both platforms and a shared scientific contract. The explicit iOS request expands the founding Mac-only platform decision; it does not retire the Mac app.
- Include the current substantive workflow, including saved methods and analysis records, in the iOS port. A limited viewer would not let the intended user conduct or document the same analysis away from the Mac.
- Preserve the unchanged source, one selected statistical rectangle, full-image application, fixed replay semantics, and explicit exports on both platforms.
- Adapt interaction and layout to touch and screen size rather than copying the Mac window and menus onto iOS.
- Share processing and document formats where possible, while isolating AppKit and UIKit or Photos and Files behavior in their respective app layers.
- Keep data local by default. Cross-device movement is an explicit import/export action, and no cloud service is a prerequisite for a useful iOS release.
- Set and test an explicit iOS resource limit during planning and implementation. If a device cannot safely process a source at full resolution, explain the limit before analysis instead of silently downsampling or risking termination.
- Decide the iOS release channel and minimum supported OS during planning and deployment based on build, signing, and device verification; the existing Mac release policy remains separate.
