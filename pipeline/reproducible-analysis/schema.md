# Schema — Reproducible Analysis

## Path

Frontend Only — no persistent application data layer is required.

In Weft's persistence sense, this path includes the native SwiftUI app, its local `KLTCore` framework, and explicit user-selected file export. The feature adds immutable in-memory analysis records and a JSON sidecar export, but it adds no database, migration, account record, project history, saved preset, imported transform, application-support file, or network endpoint.

## Confirmation

Every story and requirement in the approved PRD has been checked for persistence implications. The analysis record is computed from the current decoded source and completed transform, retained only with the current result, and discarded when that result becomes stale or the app quits. JSON exists only when the user explicitly chooses an export destination.

This intentionally supersedes the prior analysis-controls boundary that kept raw numerical values private: reproducible analysis now exposes a stable snapshot of those values. It does not change the processing algorithm or turn the record into app-managed history.

## Existing Data Used by This Feature

### `KLTCore.DecodedImage`

- Fields used: oriented `width` and `height`, source type identifier, immutable premultiplied-sRGB RGBA bytes, original image, alpha presence.
- How used: supplies the exact decoded pixel population, dimensions, and analysis basis from which a source fingerprint is created. The original buffer remains unchanged.

### `KLTCore.AnalysisInput`

- Fields used: `AnalysisMethod`, `AnalysisSampleSource`, optional `SourcePixelRegion`.
- How used: supplies stable color-space, matrix-mode, sampling-mode, and rectangular source-pixel geometry for the record.

### `KLTCore.AnalysisDescriptor`

- Fields used: input, sample pixel count, stable variable count, stable component count, limited-variation flag.
- How used: supplies the public summary of the analysis request and its stability outcome.

### `KLTCore.StretchAnalysis`

- Fields used: mean, covariance, analysis matrix, eigenvalues, eigenvectors, stable counts, output scale, degenerate flag.
- How used: supplies the mathematical intermediates already calculated by the pipeline. It must be extended to carry the final transform and the output-mapping parameters actually used to render pixels; these values must be captured during processing, never reconstructed later.

### `KLTImage.SourceIdentity`, `AnalysisRequestKey`, and `AnalysisJobIdentity`

- Fields used: source generation, immutable `AnalysisInput`, active job UUID.
- How used: remain the result-currency authority. A record becomes visible or exportable only after a completion passes both the job-ID and request-key acceptance checks.

### `KLTImage.CompletedEnhancement`

- Fields used: accepted request key and `EnhancedImage`.
- How used: becomes the owner of the immutable analysis-record snapshot used by both the inspector and JSON export.

### Existing file boundary

- Endpoints used: sandboxed AppKit open and save panels only.
- How used: a separate save panel exports JSON to a user-selected location. No application persistence, bookmark, background upload, or implicit sidecar write is added.

## New Transient Contracts

Names define responsibilities and value semantics. Exact file boundaries may follow the existing `KLTCore` and `KLTImage` organization, but the separations below must remain explicit and independently testable.

### Source fingerprint

```swift
public struct AnalysisSourceFingerprint: Equatable, Hashable, Sendable {
    public let algorithm: String       // "sha256"
    public let value: String           // lowercase hexadecimal
}

public struct AnalysisSourceDescriptor: Equatable, Sendable {
    public let displayFilename: String
    public let width: Int
    public let height: Int
    public let analysisPixelFormat: String
    public let fingerprint: AnalysisSourceFingerprint
}
```

The fingerprint input is a canonical byte stream, in this exact order:

1. ASCII domain separator `KLTImage.AnalysisSource.v1\0`.
2. Oriented width as an unsigned 64-bit big-endian integer.
3. Oriented height as an unsigned 64-bit big-endian integer.
4. ASCII pixel-format identifier `rgba8-premultiplied-srgb` followed by a zero byte.
5. The complete decoded, oriented RGBA buffer in row-major order.

SHA-256 is calculated once after decode succeeds, off the main actor, and travels with that accepted source generation. Hashing the decoded analysis source rather than the path makes renames harmless and binds the record to the pixels the algorithm actually used. The display filename remains descriptive and is never part of the fingerprint.

### Geometry and conventions

```swift
public struct NormalizedAnalysisRegion: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

public struct AnalysisRegionRecord: Equatable, Sendable {
    public let normalized: NormalizedAnalysisRegion
    public let sourcePixels: SourcePixelRegion
}

public struct AnalysisConventions: Equatable, Sendable {
    public let channelOrder: [String]
    public let channelUnits: [String]
    public let matrixStorage: String   // "row-major"
    public let regionOrigin: String    // "top-left"
    public let regionBounds: String    // "half-open"
}
```

Normalized geometry is derived from the resolved integer bounds and oriented source dimensions using `x / sourceWidth`, `y / sourceHeight`, `width / sourceWidth`, and `height / sourceHeight`. The integer half-open bounds remain the reproduction authority; normalized values support comparison across dimensions. Whole-image sampling records no region.

Channel conventions are fixed by color space:

- RGB: `red`, `green`, `blue`; unpremultiplied encoded-sRGB values normalized to `[0, 1]`.
- Lab: `L*`, `a*`, `b*`; CIE 1976 Lab values relative to D65, with units named `L-star`, `a-star`, and `b-star`.

Every vector uses this channel order. Every 3×3 matrix is row-major, with rows and columns in the same order.

### Mathematical snapshot

```swift
public struct AnalysisVector3: Equatable, Sendable {
    public let values: [Double]        // exactly three finite values
}

public struct AnalysisMatrix3: Equatable, Sendable {
    public let values: [Double]        // exactly nine finite row-major values
}

public enum AnalysisOutputMappingRecord: Equatable, Sendable {
    case rgbGlobalRange(minimum: Double, maximum: Double, scale: Double)
    case labD65ToSRGB(clipsFiniteOutOfGamutValues: Bool)
    case limitedVariationIdentity
}

public struct AnalysisMathematicsRecord: Equatable, Sendable {
    public let samplePixelCount: Int
    public let mean: AnalysisVector3
    public let covariance: AnalysisMatrix3
    public let analysisMatrix: AnalysisMatrix3
    public let eigenvalues: AnalysisVector3
    public let eigenvectors: AnalysisMatrix3
    public let transform: AnalysisMatrix3
    public let stableVariableCount: Int
    public let stableComponentCount: Int
    public let outputMapping: AnalysisOutputMappingRecord
}
```

`StretchPlan.transform` and the RGB transformed minimum and maximum must be retained in `StretchAnalysis` when they are calculated. Lab records the inverse-Lab-to-sRGB mapping and finite gamut clipping instead of pretending it uses the RGB global-range scale. Limited-variation results explicitly record the identity output path.

The symmetric eigensolver's current ordering remains binding: eigenvalues descend from largest to smallest, eigenvectors occupy corresponding columns, and each vector uses the solver's deterministic sign convention. Tests must pin ordering and orientation, including repeated and near-equal eigenvalues.

### Current analysis record

```swift
public struct AnalysisRecord: Equatable, Sendable {
    public let source: AnalysisSourceDescriptor
    public let input: AnalysisInput
    public let region: AnalysisRegionRecord?
    public let conventions: AnalysisConventions
    public let mathematics: AnalysisMathematicsRecord
    public let hasLimitedVariation: Bool
}

struct CompletedAnalysisRecord: Sendable {
    let jobID: UUID
    let requestKey: AnalysisRequestKey
    let value: AnalysisRecord
}

struct CompletedEnhancement: @unchecked Sendable {
    let key: AnalysisRequestKey
    let jobID: UUID
    let value: EnhancedImage
    let record: AnalysisRecord
}
```

`jobID` stays in memory and is not exported because it is an execution nonce and would break deterministic output. It proves that the record and image came from the same accepted completion. The exported source, request, and mathematics prove reproducibility; the workspace identities prove currency.

The processing task returns the enhanced image and mathematical record together. The main-actor workspace attaches the accepted source descriptor only after the existing job-ID and request-key gate passes, then stores one `CompletedEnhancement` snapshot. Inspector and exporter read that snapshot directly and never rebuild values from current controls.

### JSON document version 1

The durable sidecar is a dedicated export document rather than direct encoding of mutable runtime types:

```swift
struct KLTAnalysisDocumentV1: Encodable, Equatable, Sendable {
    let schema: String                 // "org.kltimage.analysis-record"
    let version: Int                   // 1
    let source: SourceV1
    let request: RequestV1
    let conventions: ConventionsV1
    let mathematics: MathematicsV1
    let interpretation: InterpretationV1
}
```

The version-1 JSON shape is:

```text
schema: "org.kltimage.analysis-record"
version: 1
source:
  filename, width, height, analysisPixelFormat
  fingerprint: { algorithm, value }
request:
  colorSpace, matrixMode, samplingMode
  region: null | { normalized: { x, y, width, height }, sourcePixels: { x, y, width, height } }
conventions:
  channelOrder[3], channelUnits[3], matrixStorage, regionOrigin, regionBounds
mathematics:
  samplePixelCount
  mean[3], covariance[9], analysisMatrix[9]
  eigenvalues[3], eigenvectors[9], transform[9]
  stableVariableCount, stableComponentCount
  outputMapping: tagged RGB-range, Lab-D65-to-sRGB, or limited-variation identity object
interpretation:
  limitedVariation, exploratoryUseNotice
```

Stable enum values are `rgb`, `lab`, `covariance`, `correlation`, `wholeImage`, and `selectedRegion`. The schema identifier, key names, enum values, array ordering, units, output-mapping tags, and exploratory-use notice are English protocol values and are not localized.

The encoder must:

- reject every non-finite value before encoding;
- use UTF-8, sorted keys, no volatile timestamp, no absolute path, and no job UUID;
- preserve enough decimal precision to round-trip each Swift `Double`;
- append one newline and otherwise produce a canonical byte sequence;
- write atomically so failure leaves no partial final-named file.

The same immutable `AnalysisRecord` must always map to byte-identical `Data`. A schema fixture and golden-byte test are the compatibility contract for version 1.

## Record Lifecycle

1. Opening or replacing a source invalidates the active job, current request key, completed enhancement, and record before decode begins.
2. A successful decode produces a fresh source generation and source descriptor, then starts analysis.
3. Changing color space, matrix mode, sampling mode, or committed rectangle creates a new request key and makes the prior enhancement and record unavailable.
4. The detached processing job calculates the enhanced pixels and mathematical snapshot from the same immutable source and request.
5. The workspace accepts the pair only when both job ID and request key match the active request; otherwise it discards both.
6. The accepted pair becomes the only record shown or exported.
7. Failure or cancellation exposes no record for the invalid or unfinished request. Relaunch restores no record.

The existing `canExport` image guard should become a shared current-result predicate used by image export, record inspection, and record export. Image and record currency must not drift.

## No Persistent Data Layer Work Required

No database schema, migration, model store, API endpoint, background service, cloud store, analytics upload, account model, or automatic sidecar is introduced. Do not add `UserDefaults`, `@AppStorage`, `SceneStorage`, SwiftData/Core Data, Application Support files, security-scoped bookmarks, extended attributes, or image metadata for this feature.

The explicit JSON export uses the same sandboxed, user-directed file boundary as existing image export, but it is a distinct action and destination. Cancel creates nothing. A write error preserves the in-memory image and record and leaves no partial final-named file.

## Engineer Handoff Checklist

- Extend the processing result to retain the final transform and exact RGB or Lab output-mapping parameters at calculation time.
- Compute one canonical SHA-256 source fingerprint after decode, off the main actor, and attach it only to the accepted source generation.
- Build the analysis record in the same detached job as the enhanced image and accept or reject them together.
- Keep execution UUIDs in memory only; export reproducibility values, not volatile bookkeeping.
- Add dedicated version-1 export DTOs and canonical finite-value encoding instead of making all runtime types generally `Codable`.
- Use one immutable completed snapshot for inspector and exporter.
- Add an atomically written `.klt-analysis.json` save path that never affects image export or source access.
- Pin the JSON contract with schema, golden-byte, round-trip, eigensystem-order, stale-result, cancellation, and failure tests.
- Preserve KLTCore/AppKit/SwiftUI boundaries, the unchanged source buffer, local-only processing, the five-second Release budget, and all existing import and image-export behavior.
