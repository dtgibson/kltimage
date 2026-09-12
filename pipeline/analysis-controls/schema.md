# Schema — Analysis Controls

## Path

Frontend Only — no persistent data-layer work is required.

In Weft's persistence sense, "Frontend Only" includes the native SwiftUI application and its local `KLTCore` framework. This feature adds in-memory scientific-processing contracts and workspace interaction state, but it adds no database, stored record, endpoint, migration, account data, project history, preference, preset, or reusable analysis artifact.

The only durable write remains the existing user-initiated PNG, TIFF, or JPEG export. An exported image is an explicit output file, not application persistence, and it must not contain the sample overlay, settings, matrices, statistics, or other reproducibility metadata.

## Classification Verification

Every story and requirement in the approved PRD was checked for persistence implications:

| PRD trace | Runtime responsibility | Persistence conclusion |
|---|---|---|
| US-01 | Choose RGB or Lab for the current workspace. | In-memory choice only. |
| US-02 | Choose covariance or correlation for the current workspace. | In-memory choice only. |
| US-03 | Use one rectangle as the statistical sample for the open source. | In-memory source-pixel geometry only. |
| US-04 | Edit that geometry by keyboard, VoiceOver, or pointer. | UI draft and committed runtime geometry only. |
| US-05 | Keep the requested and completed method identities visible. | Runtime request/result association only. |
| US-06 | Preserve comparison and explicit image export. | Uses existing in-memory images and file export; no records. |
| US-07 | Explain invalid or weak requests without fallback. | Runtime validation state only. |
| FR-01–FR-03 | Three independent choices, launch defaults, and exact method identity. | Plain value types in workspace memory; launch defaults are constants, not preferences. |
| FR-04–FR-12 | RGB/Lab conversion, covariance/correlation plans, full-image application, and all eight combinations. | Pure/local `KLTCore` processing over the decoded buffer. |
| FR-13–FR-22 | Whole/region sampling, one editable rectangle, source-coordinate mapping, validation, reuse, and new-source reset. | Transient region and viewport state; opening a source clears image-specific state. |
| FR-23 | Do not persist choices or regions after quit. | Explicitly prohibits a persistence implementation. |
| FR-24–FR-27 | Recalculation, cancellation/supersession, updating, stale-result, and failure recovery. | Task identity and state-machine data live in `WorkspaceModel`. |
| FR-28–FR-32 | Immutable source, alpha safety, comparison, current-result export, format/import regression. | Existing in-memory buffers plus existing explicit file access. |
| FR-33–FR-34 | Method and exploratory-use guidance. | Derived presentation copy; no stored content. |
| FR-35 | Do not display or export reproducibility data. | Explicitly excludes settings/matrix/statistics artifacts. |
| FR-36 | Reject oversized or invalid first-frame dimensions before full decode and revalidate decoded dimensions. | Pure `KLTCore` import-policy validation; no stored data. |
| NFR-01–NFR-05 | Numerical correctness, compatibility, determinism, performance, and responsiveness. | Algorithm and execution constraints, not stored data. |
| NFR-06–NFR-08 | Accessibility, visual consistency, and platform compatibility. | Presentation and platform constraints only. |
| NFR-09 | Local-only pixels, coordinates, statistics, and results. | Prohibits network or remote persistence. |
| NFR-10 | Independently testable conversion, analysis, coordinates, cancellation, and ordering. | Pure/testable runtime contracts and fixtures only. |
| NFR-11 | Keep full-frame image memory within the documented 64-megapixel product budget. | Runtime allocation policy only; no persistence. |

No story or requirement calls for storage. The out-of-scope list additionally excludes saved settings, regions, presets, matrices, analyses, manifests, numerical reports, and transformation-data exports.

## Existing Runtime Data

### `KLTCore.DecodedImage`

The current source contract contains oriented `width` and `height`, source type identity, `hasAlpha`, an `originalImage`, and an internal 8-bit premultiplied-sRGB RGBA buffer. The buffer is the immutable calculation source for every request. It must never be replaced by or populated from an enhanced result.

Compatibility details that remain binding:

- Decode applies source orientation and creates the oriented, 8-bit sRGB working image.
- The RGBA buffer and `CGImage` share the same oriented dimensions.
- Color samples are obtained by unpremultiplying RGB. Alpha is not a statistical variable.
- Every oriented source-pixel position remains in the population, including transparent positions; a fully transparent position retains the shipped zero-RGB sampling behavior.
- The original `CGImage` and bytes remain unchanged for comparison and retry.

### `KLTCore.EnhancedImage` and `StretchAnalysis`

`EnhancedImage` currently owns the full-resolution enhanced `CGImage`, internal RGBA bytes, `StretchAnalysis`, and an optional limited-variation notice. `StretchAnalysis` contains mean, covariance, eigensystem, stable-component count, output scale, and a degenerate flag.

These remain ephemeral diagnostic inputs to presentation and tests. This feature may extend the analysis/result contract with method and stability metadata, but must not make it `Codable`, persist it, expose raw numerical fields in the interface, or place it in exported image metadata. The next Reproducible analysis roadmap item owns any future durable representation.

### `KLTCore` numerical internals

`RunningCovariance3`, `StretchPlan`, and `Matrix3x3` already supply deterministic online sample covariance, symmetric eigendecomposition, bounded stable-component gains, and transform application. They remain processing-layer types rather than workspace records.

### `KLTCore.ImageProcessingLimits`

The full-frame pipeline has one public, testable import policy: at most 64,000,000 pixels and four RGBA bytes per pixel. Metadata dimensions are validated with reporting-overflow arithmetic before ImageIO receives a full-resolution decode request. The oriented decoder output passes through the same validation before allocation. The fixed product ceiling does not expand from live free-memory readings, which are volatile and cannot guarantee later transform or export allocations.

### `KLTImage.WorkspaceModel`

The current main-actor model holds source/result images, workspace phase, comparison mode, synchronized zoom/pan, an active detached task, and a UUID operation guard. Analysis controls extend this state; they do not create a persistence model.

## Proposed Transient Contracts

Names below define responsibilities and value semantics for the Engineer. Exact file boundaries may follow the existing `KLTCore`/`KLTImage` split, but equivalent concepts must remain explicit and independently testable.

### Core analysis values (`KLTCore`)

```swift
public enum AnalysisColorSpace: String, CaseIterable, Sendable {
    case rgb
    case lab
}

public enum AnalysisMatrixMode: String, CaseIterable, Sendable {
    case covariance
    case correlation
}

public enum AnalysisSampleSource: String, CaseIterable, Sendable {
    case wholeImage
    case selectedRegion
}

public struct AnalysisMethod: Equatable, Hashable, Sendable {
    public let colorSpace: AnalysisColorSpace
    public let matrixMode: AnalysisMatrixMode

    public static let baseline = AnalysisMethod(
        colorSpace: .rgb,
        matrixMode: .covariance
    )
}
```

The launch request is `.baseline` plus `.wholeImage`. These are constants, not values loaded from `UserDefaults`.

### Source-pixel region (`KLTCore`)

```swift
public struct SourcePixelRegion: Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
}

public enum RegionValidationIssue: Equatable, Sendable {
    case missing
    case nonPositiveSize
    case outsideSource(sourceWidth: Int, sourceHeight: Int)
    case fewerThanFourPixels
    case insufficientVariation(stableComponentCount: Int)
}

public struct ValidatedSourcePixelRegion: Equatable, Hashable, Sendable {
    public let bounds: SourcePixelRegion
    public let pixelCount: Int
}
```

`SourcePixelRegion` deliberately permits invalid attempted values. Numeric fields and a completed direct edit must retain what the user entered so the exact problem can be corrected. A pure validator is the only path to `ValidatedSourcePixelRegion`; it performs overflow-safe end-coordinate and pixel-count checks and returns a specific issue. It never clamps, expands, normalizes, or substitutes whole-image sampling.

The variation check is method-dependent and therefore follows geometric validation and sample accumulation. A selected region becomes processable only when geometry is valid, contains at least four pixels, and produces at least one stable component for the requested color space/matrix mode.

### Processing input and output (`KLTCore`)

```swift
public struct AnalysisInput: Equatable, Hashable, Sendable {
    public let method: AnalysisMethod
    public let sampleSource: AnalysisSampleSource
    public let region: SourcePixelRegion?

    public static let baseline = AnalysisInput(
        method: .baseline,
        sampleSource: .wholeImage,
        region: nil
    )
}

public struct AnalysisDescriptor: Equatable, Hashable, Sendable {
    public let input: AnalysisInput
    public let samplePixelCount: Int
    public let stableVariableCount: Int
    public let stableComponentCount: Int
    public let hasLimitedVariation: Bool
}
```

`ImagePipeline.enhance(_:input:)` validates and calculates one explicit request. `ImagePipeline.enhance(_:)` should remain as a baseline wrapper, or an equivalent golden-test seam must be retained, so existing callers and byte-identity fixtures continue to exercise RGB + covariance + whole image unchanged.

An `EnhancedImage` is associated with the `AnalysisDescriptor` that actually produced it. The descriptor contains method identity and non-sensitive summary data needed by status/guidance; raw matrices and per-variable numerical reports stay in `StretchAnalysis` for internal tests only.

### Workspace request identity (`KLTImage`)

```swift
struct SourceIdentity: Equatable, Hashable, Sendable {
    let generation: UUID
}

struct AnalysisRequestKey: Equatable, Hashable, Sendable {
    let source: SourceIdentity
    let input: AnalysisInput
}

struct AnalysisJobIdentity: Equatable, Sendable {
    let id: UUID
    let key: AnalysisRequestKey
}

struct CompletedEnhancement: Sendable {
    let key: AnalysisRequestKey
    let value: EnhancedImage
}
```

`AnalysisRequestKey` expresses scientific equivalence: same decoded source generation, color space, matrix mode, sample source, and exact integer region. `AnalysisJobIdentity.id` expresses execution recency when an equivalent request is issued more than once.

The workspace accepts a completion only when both conditions hold:

1. the completed job ID equals the active job ID; and
2. its key equals the workspace's currently requested key.

Cancellation is still requested for superseded work, but identity checks—not cooperative cancellation timing—are the correctness boundary. A late result, failure, or cancellation callback from an older source or configuration is ignored. Export is enabled only when `completedEnhancement.key == currentRequestKey` and the current status is successfully ready.

Import/decode, analysis, and export should have distinct operation identities or a typed operation identity. A source receives a fresh `SourceIdentity` only after its decode is accepted. Opening another file invalidates all prior analysis/export jobs before any callback can mutate the new workspace.

### Workspace state (`KLTImage`)

The workspace needs separate current-request state and last-completed-result state; a single `phase` plus a nullable result is no longer enough because a previous result remains visible while a replacement is processing or invalid.

```swift
enum AnalysisRequestStatus: Equatable {
    case awaitingImage
    case awaitingRegion(RegionValidationIssue)
    case invalidRegion(RegionValidationIssue)
    case processing(AnalysisJobIdentity)
    case ready
    case failed(message: String)
}

struct RegionEditorState: Equatable {
    var committed: SourcePixelRegion?
    var draftX: String
    var draftY: String
    var draftWidth: String
    var draftHeight: String
    var validationIssue: RegionValidationIssue?
}
```

The numeric draft fields are strings so an empty, partial, signed, overflowed, or otherwise invalid edit can remain visible without manufacturing a valid integer. A validated commit updates `committed`; an invalid commit retains the draft/attempt and changes status without launching analysis. Pointer editing may constrain its live proposal to the source bounds before commit; numeric committed input must never be silently clamped.

Required in-memory lifecycle:

- App launch: RGB, covariance, whole image, no region.
- Method change: retain the current source and committed region, update the current request, and recalculate when its sample is valid.
- Select-region with no region: enter `awaitingRegion`, launch no fallback calculation, and make any prior result stale.
- Select-region with a valid existing region: reuse it and recalculate.
- Switch to whole image: retain the region but mark it inactive, then recalculate from whole-image statistics.
- Clear region while selected-region sampling is active: remove the committed region, retain an editable empty draft, enter `awaitingRegion`, and disable export.
- Open a different source: cancel/invalidate prior work, clear region/editor state, choose whole image, reset comparison/zoom/pan, retain color-space and matrix choices for this app session, and calculate from the new immutable source.
- App termination/relaunch: discard all of the above and restore launch defaults.
- Recalculation/failure: retain the prior completed enhancement for comparison, but label it stale and keep export disabled until the current key completes.

None of these types should adopt `Codable` for this feature, and none should be written to `UserDefaults`, Application Support, sidecars, extended attributes, exported-image metadata, or a network service.

## Source-Coordinate Contract

`SourcePixelRegion` is the single canonical rectangle used by validation, sampling, numeric editing, overlays, request identity, and tests.

- Coordinates describe the oriented decoded source, never the pre-orientation file and never a SwiftUI view.
- The public/UI origin is the upper-left source corner; `x` increases right and `y` increases down. The interface must state this origin.
- Bounds are integer pixel-edge coordinates and use half-open intervals: `[x, x + width)` × `[y, y + height)`.
- A valid integer region therefore selects exactly columns `x ..< x + width` and rows `y ..< y + height`; this is equivalent to including pixels whose centers lie inside the bounds.
- Valid geometry requires `x >= 0`, `y >= 0`, `width > 0`, `height > 0`, `x + width <= source.width`, and `y + height <= source.height`, with overflow checked before addition/multiplication.
- Any difference between Core Graphics backing-row order and the upper-left public coordinate system is handled once in a tested buffer-index adapter. It must not leak into the region type or UI.
- Direct manipulation maps pane coordinates through the inverse of one explicit viewport transform: pane center/fit placement, then shared pan, then shared zoom. Edge snapping is deterministic (`floor` for the lesser edge, `ceil` for the greater edge), with the live pointer proposal constrained before commit.
- Overlay rendering uses the forward transform from the same source bounds. Original, Enhanced, and both Split panes receive the same canonical rectangle; each pane computes only its own fit/placement transform.
- Switching comparison mode, fitting, zooming, or panning changes viewport transforms only. It never rewrites region bounds.
- The overlay is a SwiftUI presentation layer and never touches `DecodedImage.rgba8Premultiplied`, `EnhancedImage.rgba8Premultiplied`, or the exported `CGImage`.

Coordinate conversion should live in a pure, non-view helper (for example, `ImageViewportTransform`) so edge, split-pane, zoom, pan, replacement, and round-trip fixtures can test it without launching the production UI.

## Scientific Processing Boundary

All color conversion, sampling, matrix construction, stability decisions, transformation, output mapping, and cancellation checkpoints belong in `KLTCore`. `WorkspaceModel` supplies an immutable `DecodedImage` plus `AnalysisInput`; SwiftUI never calculates statistics or edits pixel buffers.

### Common pipeline

For every valid request:

1. Read only the unchanged decoded, oriented 8-bit premultiplied-sRGB buffer.
2. Convert each sampled pixel to its three-variable working value (unpremultiplied encoded sRGB or CIE L*a*b* D65). Alpha is never a fourth variable.
3. Accumulate sample mean and sample covariance (`n - 1` denominator) using either the full pixel population or exactly the validated source region.
4. Build the requested covariance or correlation plan with documented stability masks and bounded gains.
5. Apply that one plan to every source pixel at full resolution, including pixels outside a selected region.
6. Map the transformed working value to displayable sRGB, preserve the original alpha byte, and create a separate output buffer/image.
7. Return the result only if every required intermediate is finite; otherwise return a typed, readable processing failure.

Cancellation checks remain inside all full-image and sample loops. Sampling and transformation should avoid allocating a second full-image Lab array; pure per-pixel conversion keeps the 24-megapixel memory and time profile bounded.

### RGB compatibility branch

RGB variables are the shipped unpremultiplied encoded-sRGB values. RGB + covariance + whole image must continue through the existing accumulation, eigendecomposition, gain, transformed-extrema scan, uniform output-scale, rounding, premultiplication, and byte creation path without a new arithmetic reordering. It must remain pixel-identical for opaque, transparent, ordinary, and degenerate golden fixtures.

RGB region mode changes only the pixels supplied to the statistics accumulator; the resulting plan and the full-image transformed-extrema/output passes use the unchanged existing RGB behavior. RGB correlation changes matrix-plan construction but retains the RGB full-image output mapping and alpha behavior.

### Lab D65 branch

Lab conversion is a pure, deterministic boundary over unpremultiplied encoded sRGB:

- Decode the standard sRGB transfer function to linear RGB.
- Convert linear RGB to XYZ using the standard sRGB/D65 matrix and reference white `(0.95047, 1.00000, 1.08883)`.
- Convert XYZ to CIE 1976 L*a*b* using `delta = 6/29` and the standard piecewise `f(t)` definition.
- Perform sampling, centering, matrix analysis, and transform application in raw Lab units (`L*`, `a*`, `b*`), not normalized pseudo-RGB values.
- Convert every transformed Lab value through inverse Lab → XYZ D65 → linear sRGB → encoded sRGB.
- Treat any non-finite conversion or transform value as failure. Clip each finite encoded-sRGB channel to `[0, 1]` only after inverse conversion. Preserve and reapply the source alpha byte exactly.

The RGB global extrema/output-scale step must not be applied to `L*`, `a*`, and `b*` as though they were three unit RGB channels. Lab produces display values by inverse color conversion plus finite gamut clipping. Constants, threshold inequalities, and rounding live in one implementation and are covered by published reference-color and out-of-gamut fixtures.

### Covariance and correlation plans

Covariance mode keeps the current sample covariance and deterministic symmetric eigendecomposition. Stable eigencomponents use the shipped scale-relative gain boundary:

```text
componentFloor = max(absoluteVarianceFloor,
                     largestEigenvalue / maximumStableGain²)
```

Components below that floor are not amplified. The existing values (`absoluteVarianceFloor = 1e-12`, `maximumStableGain = 32`) remain the baseline unless changing them is separately justified and golden-tested.

Correlation mode first determines stable input variables from the covariance diagonal with a corresponding scale-relative boundary:

```text
variableFloor = max(absoluteVarianceFloor,
                    largestVariableVariance / maximumStableGain²)
```

For stable variables only, construct `R[i,j] = C[i,j] / (sigma[i] * sigma[j])`, with an exact unit diagonal. Unstable variables never participate in a division or stable-subspace cross-term. Decompose and apply the correlation plan only in the stable-variable subspace; unstable variable deltas pass through with unit gain and no cross-mixing. Correlation mode is never replaced by covariance mode.

Plan application uses the same stable-variable standardization convention used to build `R`; it must be encapsulated by the plan rather than reconstructed in UI code. Every computed matrix term, eigenvalue/vector, gain, and transformed value must be finite. A selected region with no stable variable/component returns `.insufficientVariation`; a whole-image degenerate case retains the shipped readable limited-variation behavior. Any partial stability is reported through `AnalysisDescriptor` for status and guidance.

## Result Currency and Export Contract

The workspace simultaneously tracks:

- the current visible control/region request (`currentRequestKey`);
- the active job, if any;
- the last successfully completed enhancement and its key; and
- whether that completed enhancement is current or retained-but-stale.

Changing any method value, sample source, or committed region creates a new request key and immediately makes a mismatched completed result stale. While processing, invalid, awaiting region, failed, or stale, the previous image may remain visible for comparison but `canExport` is false. A result becomes current/exportable only after an accepted completion with an exact matching key. Export captures that current `CompletedEnhancement` value before starting and writes only its full-resolution image buffer.

Method/status copy is derived from the current request while processing and from the completed descriptor after success. Presentation must never label a stale previous image with the newer method.

## Data-Layer and Compatibility Constraints

- No database schema, migration, repository, backend, API endpoint, cloud store, analytics upload, account model, or network permission is introduced.
- No app-session state is restored after quit. In particular, do not add `@AppStorage`, `SceneStorage`, `UserDefaults`, SwiftData/Core Data, sidecars, security-scoped bookmarks, or settings files for analysis choices or geometry.
- Existing sandboxed open/save panels and temporary security-scoped access remain the only file-boundary mechanism.
- Declared and decoded first-frame dimensions must pass `ImageProcessingLimits` before full-frame decode and app-owned RGBA allocation respectively; the supported ceiling is 64,000,000 pixels.
- JPEG, PNG, TIFF, and HEIC decode/orientation behavior remains unchanged.
- PNG/TIFF transparency, JPEG opaque export, explicit destination selection, replacement confirmation, cancellation, source dimensions, and full-resolution output remain unchanged.
- Original, Split, and Enhanced modes continue to share zoom/pan. Region state is orthogonal to comparison presentation.
- macOS 14+, Swift 6 concurrency checking, Apple Silicon, and Intel compatibility remain required.
- Processing stays local, cancellable, deterministic, and off the main actor; observable workspace mutation stays on the main actor.
- `KLTCore` remains free of SwiftUI and AppKit presentation concerns, and coordinate/color/matrix/request-ordering logic remains testable outside production views.
- Raw matrices, eigenvectors, per-channel statistics, manifests, and numerical reports are not displayed or exported in this build.

## Engineer Handoff Checklist

- Preserve a byte-identical baseline entry point and golden fixtures before branching into new modes.
- Add explicit value types for method, sampling, raw/validated region, result descriptor, source identity, request key, and execution identity.
- Keep raw numeric editor drafts separate from validated committed geometry.
- Centralize and test upper-left oriented-source ↔ backing-buffer/view transforms.
- Make region accumulation separate from full-image transform application.
- Encapsulate RGB and Lab output mappings; do not apply RGB unit-range logic to Lab variables.
- Encapsulate covariance/correlation construction and stable-variable/component masks without fallback.
- Retain a prior result as stale during recalculation/failure, and gate result acceptance/export on exact request identity.
- Add no persistence and no network path.
