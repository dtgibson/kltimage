# Schema — Custom Color Spaces and Reusable Transforms

## Path

Incremental — extend the shipped native application and `KLTCore` architecture.

The most recent cumulative baseline is `pipeline/reproducible-analysis/schema.md`. Its decoded-source fingerprint, source-coordinate contract, immutable completed-result snapshot, request/job acceptance gate, version-1 analysis document, local-only file boundary, cancellation behavior, and 64-megapixel ceiling remain binding. The earlier Analysis Controls and Core RGB schemas remain binding where the later schema did not supersede them.

This feature is the first intentional application-managed persistence addition. It adds one bounded local method-library file for user working spaces and saved transform recipes. It does not add a backend, database, image history, project, source bookmark, network endpoint, account, or synchronization path.

## Confirmation

The approved PRD requires both persistent user methods and exact frozen replay. A frontend-only/no-data-change path is therefore no longer sufficient. Persistence stays inside the macOS sandbox under Application Support and is owned by the app target; portable artifact validation, deterministic encoding, working-space mathematics, recipe capture, and replay stay in `KLTCore`.

The two library artifact types are deliberately not interchangeable:

- A **working-space revision** defines reversible coordinates in which a new image-specific covariance/correlation plan is calculated.
- A **transform recipe** snapshots a completed calculated result and replays its fixed centering, transform, inverse mapping, and output mapping. A replay never reads target statistics.

An analysis record remains documentary. Neither version 1 nor version 2 analysis JSON is accepted by either method importer.

## Cumulative Existing Data and Invariants

### Decoded source

`DecodedImage` remains the immutable, oriented, first-frame, 8-bit premultiplied-sRGB source. Its upper-left row-major RGBA bytes, oriented dimensions, alpha behavior, supported JPEG/PNG/TIFF/HEIC inputs, and `KLTImage.AnalysisSource.v1\0` SHA-256 fingerprint contract do not change. The display filename remains descriptive and is not part of the fingerprint.

All calculations and replays start from those unchanged bytes. No method operation mutates, relocates, annotates, or writes beside the source.

### Existing analysis controls and numerical plan

Covariance/correlation semantics, `n - 1` accumulation, stable-variable/component rules, `absoluteVarianceFloor = 1e-12`, `maximumStableGain = 32`, deterministic eigensystem ordering/sign, selected-region half-open geometry, full-frame application, and limited-variation behavior remain unchanged.

The exact existing `ImagePipeline.enhance(_:)` RGB + covariance + whole-image branch remains the baseline pixel-compatibility seam. The existing standard RGB and standard Lab calculation branches must retain their current operation order and fixtures. New affine spaces use a new generic branch; the standard branches are not rewritten to pass through it.

### Existing result and record currency

The current result is still accepted only when both the processing job UUID and the full current request key match. The enhanced pixels, applied method snapshot, and analysis record are returned by one detached job and accepted or discarded together. Changing source, mode, mathematical working-space revision, recipe, matrix mode, sampling mode, or committed region makes a mismatched completed result stale immediately.

Image export, Save Transform, record inspection, and record export all derive from the same accepted immutable `CompletedEnhancement`; none reconstructs a method from mutable controls or the current library.

## Working-Space Domain Model

### Identity, revision, and library metadata

Use distinct value types rather than a generic preset dictionary:

```swift
public struct WorkingSpaceIdentity: Equatable, Hashable, Sendable {
    public enum Kind: String, Equatable, Hashable, Sendable { case standard, curated, user }
    public let kind: Kind
    public let identifier: String
}

public enum WorkingSpaceBase: String, Equatable, Hashable, Sendable {
    case encodedSRGB = "encoded-srgb"
    case cieLabD65 = "cie-lab-d65"
}

public enum WorkingSpaceOutputBehavior: String, Equatable, Hashable, Sendable {
    case encodedSRGBGlobalRangeV1 = "encoded-srgb-global-range-v1"
    case cieLabD65ToClippedSRGBV1 = "cie-lab-d65-to-clipped-srgb-v1"
}

public struct WorkingSpaceRevision: Equatable, Hashable, Sendable {
    public let identity: WorkingSpaceIdentity
    public let definitionVersion: Int
    public let base: WorkingSpaceBase
    public let baseChannelOrder: [String]       // exactly 3
    public let baseChannelUnits: [String]       // exactly 3
    public let workingChannelNames: [String]    // exactly 3
    public let forward: Matrix3x3               // A, row-major
    public let offset: SIMD3<Double>            // b
    public let inverse: Matrix3x3               // validated inverse of A
    public let outputBehavior: WorkingSpaceOutputBehavior
}

public struct UserWorkingSpaceItem: Equatable, Sendable {
    public let libraryName: String
    public let purpose: String?
    public let revision: WorkingSpaceRevision
    public let createdAt: Date
    public let modifiedAt: Date
}
```

`libraryName`, `purpose`, and timestamps are library metadata, not mathematical identity. Renaming updates `modifiedAt` but does not change `definitionVersion`, invalidate a current result, or mutate a captured record/recipe. Changing the base, any channel name, any forward coefficient, any offset, or output behavior creates `definitionVersion + 1` under the same user identifier. The store retains only the current library revision; accepted results and recipes retain their own immutable earlier snapshots.

Standard identifiers are `org.kltimage.space.rgb` and `org.kltimage.space.lab-d65`. User identifiers are canonical lowercase UUID strings. Curated identifiers are the three allowlisted reverse-DNS strings in the curated table below. Standard and curated identities cannot be replaced by imported content.

### Base conventions

The conventions are fixed, not user-editable:

| Base | Channel order | Units | Required output behavior |
|---|---|---|---|
| `encoded-srgb` | `red`, `green`, `blue` | `encoded-srgb-[0,1]` for each channel | `encoded-srgb-global-range-v1` |
| `cie-lab-d65` | `L*`, `a*`, `b*` | `L-star`, `a-star`, `b-star` | `cie-lab-d65-to-clipped-srgb-v1` |

Imported convention arrays and output behavior must exactly match the selected base. They are included in portable snapshots for transparency and confused-deputy detection, but they never select arbitrary code.

### Affine definition

For base vector `x`, every custom or curated space is exactly:

```text
w = A × x + b
x = A⁻¹ × (w - b)
```

Rows name output channels; columns follow the declared base channel order. Matrix arrays are row-major. Each dot product uses the shared `Matrix3x3` implementation and one fixed left-to-right operation order. The inverse used at runtime is the inverse stored in the validated revision; locally created/edited definitions receive the deterministic inverse derived by the validator.

Affine offsets are coordinate conventions. Because analysis centers in working coordinates, an offset ordinarily cancels algebraically from a calculated affine result; it is nevertheless validated, displayed, versioned, and frozen so the complete coordinate definition remains honest.

### Validation and numerical bounds

Untrusted arrays are length-checked before constructing `Matrix3x3`; an importer must never reach the current precondition-based initializer with a wrong count. `WorkingSpaceValidator` is a pure `KLTCore` boundary used by curated definitions, editor drafts, the local store, imports, calculations, and recipes.

Validation runs in this order and returns a specific typed issue:

1. Identity kind/identifier, `definitionVersion` in `1...2_147_483_647`, and fixed base conventions are valid.
2. Library name after trimming is 1–80 Unicode scalar values; each working-channel name is 1–40; optional purpose is at most 500. NUL and Unicode control characters are rejected. An imported display filename is descriptive-only, 1–255 Unicode scalar values, and cannot contain NUL or `/`; it is never interpreted as a path.
3. Arrays contain exactly 9/3 values and every `Double` is finite.
4. Every forward coefficient has absolute value at most `100`; every offset has absolute value at most `10_000`.
5. Let `s = max(abs(A[i,j]))`. Require `s > 0`, then require `abs(det(A / s)) >= 1e-12`.
6. Derive the inverse with the shared explicit 3×3 adjugate/determinant routine. Every inverse term must be finite and have absolute value at most `1_000`.
7. Compute the transparent infinity-norm condition number `kappaInfinity = maxRowSum(abs(A)) × maxRowSum(abs(AInverse))`; require `kappaInfinity <= 1_000`.
8. For imported content, require both `A × suppliedInverse` and `suppliedInverse × A` to differ from identity by no more than `1e-10` in maximum absolute element and require each supplied inverse value to differ from the derived value by no more than `1e-12 × max(1, abs(derived))`.
9. Evaluate the forward and inverse reference-domain corner fixtures for the declared base and require finite results. Processing still rejects any non-finite per-pixel intermediate at runtime.

Bounds are inclusive. There is no clamp, coefficient normalization, pseudoinverse, fallback space, or automatic repair. The editor preserves invalid draft strings for correction; only a validated revision can enter a request or store.

### Curated revision 1 definitions

Curated revisions are compile-time values, pass through the same validator at startup/tests, and are never persisted. Their names and purposes are KLT Image language, not DStretch compatibility claims.

| Identifier / name | Base | Working channels | `A` rows | `b` | Purpose |
|---|---|---|---|---|---|
| `org.kltimage.space.luma-chroma` / **Luma + Chroma** | encoded sRGB | `luma`, `blue-minus-luma`, `red-minus-luma` | `[0.2126, 0.7152, 0.0722]`; `[-0.2126, -0.7152, 0.9278]`; `[0.7874, -0.7152, -0.0722]` | `[0, 0, 0]` | Separates overall encoded-sRGB luma from blue/luma and red/luma differences. |
| `org.kltimage.space.red-complement` / **Red + Complement** | encoded sRGB | `luma`, `red-minus-complement`, `green-minus-blue` | `[0.2126, 0.7152, 0.0722]`; `[1, -0.5, -0.5]`; `[0, 1, -1]` | `[0, 0, 0]` | Gives red-versus-the-green/blue average its own exploratory coordinate while retaining luma and the remaining chroma axis. |
| `org.kltimage.space.lab-blue-yellow` / **Lab Blue–Yellow** | CIE Lab D65 | `lightness`, `red-green-reduced`, `yellow-blue-expanded` | `[1, 0, 0]`; `[0, 0.5, 0]`; `[0, 0, 2]` | `[0, 0, 0]` | Weights the Lab `b*` yellow/blue axis relative to `a*` while preserving an invertible, inspectable basis. |

All have `definitionVersion = 1`. The first two use `encoded-srgb-global-range-v1`; the third uses `cie-lab-d65-to-clipped-srgb-v1`.

Pinned definition fixtures:

| Definition | Input base vector | Expected working vector | Expected inverse characteristics |
|---|---|---|---|
| Luma + Chroma | `[0.25, 0.5, 0.75]` | `[0.4649, 0.2851, -0.2149]` | Rows approximately `[1, 0, 1]`, `[1, -0.10095078299776286, -0.29725950782997765]`, `[1, 1, 0]`; `kappaInfinity = 3.7112` |
| Red + Complement | `[0.8, 0.3, 0.1]` | `[0.39186, 0.6, 0.2]` | Rows approximately `[1, 0.7874, -0.3215]`, `[1, -0.2126, 0.1785]`, `[1, -0.2126, -0.8215]`; `kappaInfinity = 4.2178` |
| Lab Blue–Yellow | `[62, 18, -24]` | `[62, 9, -48]` | Exact diagonal inverse `[1, 2, 0.5]`; `kappaInfinity = 4` |

Each round-trip must recover the input within `1e-12` per component. Pin validator boundary fixtures as well: `diag(1,1,0)` is singular; `diag(1,1,0.0009)` exceeds the condition limit; `diag(1,1,0.001)` is accepted at `kappaInfinity = 1000`; uniform `diag(0.0005,0.0005,0.0005)` fails the inverse-term bound even though it is well-conditioned; `100.0000000001` and `10_000.0000000001` fail their respective bounds.

## Calculation and Replay Contracts

### Execution request

Replace the assumption that every request is calculated with an explicit tagged request:

```swift
public enum WorkingSpaceSelection: Equatable, Hashable, Sendable {
    case standardRGB
    case standardLabD65
    case affine(WorkingSpaceRevision)
}

public struct CalculatedAnalysisRequest: Equatable, Hashable, Sendable {
    public let workingSpace: WorkingSpaceSelection
    public let matrixMode: AnalysisMatrixMode
    public let sampleSource: AnalysisSampleSource
    public let region: SourcePixelRegion?
}

public enum EnhancementExecutionRequest: Equatable, Hashable, Sendable {
    case calculated(CalculatedAnalysisRequest)
    case replayed(TransformRecipeSnapshot)
}
```

Retain the current `AnalysisInput` and `AnalysisMethod(colorSpace:matrixMode:)` initializers as source-compatible wrappers for standard RGB/Lab calculated requests. `.baseline` remains standard RGB + covariance + whole image. `AnalysisColorSpace` retains its existing `rgb` and `lab` raw values; it is not expanded with unstable user identifiers.

The app request key becomes source generation plus the full immutable execution request (or its canonical SHA-256 mathematical digest plus the retained snapshot). A working-space key includes identity, definition version, all mathematical fields, and inverse, but excludes mutable library name/purpose/timestamps. A recipe key includes its identity and canonical recipe digest. This prevents same-ID malformed replacements from aliasing existing work.

### Calculated affine pipeline

For curated and user working spaces, `KLTCore` performs exactly:

1. Validate the revision before starting any pixel loop.
2. Convert each sampled unchanged pixel to base `x`: current unpremultiplied encoded sRGB, or current CIE Lab D65.
3. Compute `w = A × x + b` and accumulate the selected population in `Double`.
4. Build the existing covariance/correlation `StretchPlan`, centered on `muW`, with no altered stability rule.
5. For every full-frame source pixel compute:

   ```text
   w       = A × x + b
   wPrime  = muW + T × (w - muW)
   xPrime  = AInverse × (wPrime - b)
   ```

6. Apply the base-owned output behavior:
   - encoded sRGB: scan all components of `xPrime` for one global `minimum`/`maximum`, freeze `scale = 1 / (maximum - minimum)`, then clamp `(xPrime - minimum) × scale` to `[0,1]` and use the existing premultiplied-byte rounding;
   - CIE Lab D65: run the existing inverse Lab D65 → encoded-sRGB conversion, then clip finite out-of-gamut encoded channels to `[0,1]` and use the existing premultiplied-byte rounding.
7. Preserve the original alpha byte exactly and publish only after all finite/cancellation checks pass.

The encoded-sRGB rule is applied **after** the inverse affine mapping. With identity `A` and zero `b`, it is mathematically the current RGB rule. Nevertheless standard RGB continues through its original code path to prevent arithmetic reordering. Standard Lab does the same.

Selected-region degeneracy still fails without whole-image fallback. A whole-image degenerate result remains an identity/limited-variation result and cannot be saved as a recipe. Partially stable calculated results remain visible but `hasLimitedVariation == true`, so Save Transform is unavailable as required.

### Frozen transform recipe

```swift
public struct TransformRecipeSnapshot: Equatable, Hashable, Sendable {
    public let identifier: UUID
    public let recipeFormatVersion: Int          // 1
    public let algorithm: AlgorithmVersion
    public let workingSpace: WorkingSpaceRevision
    public let workingSpaceNameAtCapture: String
    public let originatingAnalysis: OriginatingAnalysis
    public let originSource: AnalysisSourceDescriptor
    public let workingCenter: SIMD3<Double>      // muW
    public let transform: Matrix3x3              // T in working coordinates
    public let outputMapping: FrozenOutputMapping
    public let exploratoryUseNotice: String
}

public enum FrozenOutputMapping: Equatable, Hashable, Sendable {
    case encodedSRGBGlobalRangeV1(
        minimum: Double,
        maximum: Double,
        scale: Double,
        clipsToUnitRange: Bool
    )
    case cieLabD65ToClippedSRGBV1(
        referenceWhite: SIMD3<Double>,
        clipsFiniteOutOfGamutValues: Bool
    )
}
```

`AlgorithmVersion` is `{ identifier: "org.kltimage.decorrelation-stretch", version: 1 }`. It pins the shipped covariance/correlation, centering, color-conversion, output, alpha, and quantization conventions. A future incompatible calculation/replay implementation must use another supported version rather than reinterpreting version 1.

`OriginatingAnalysis` contains stable matrix mode, sampling mode, exact optional source-pixel/normalized region, and sample pixel count. It is provenance only during replay. The recipe intentionally does not depend on the live library revision, current controls, target statistics, or an analysis-record file.

A recipe is captured only from the accepted completed calculated snapshot when all are true: result and record are current; execution is calculated; processing succeeded; the result is not identity/degenerate; `hasLimitedVariation == false`; and every recipe field validates. Capture copies `workingCenter`, `transform`, and output mapping directly from the `StretchAnalysis` that rendered the pixels. It never recalculates or reads controls. Standard RGB/Lab are represented in the recipe by identity working-space revisions with their fixed base conventions.

Recipe validation permits only the algorithm/version above, format version 1, a valid embedded working-space snapshot, a valid source descriptor within 64 MP, finite center/transform/mapping values, transform coefficients with absolute value at most `2_048`, center values with absolute value at most `100_000`, and output extrema with absolute value at most `1_000_000_000`. An encoded-sRGB mapping requires `maximum - minimum > 1e-12`, `scale > 0`, and `scale` within `1e-12 × max(1, expectedScale)` of `1 / (maximum - minimum)`. A Lab mapping requires the exact D65 white `[0.95047, 1, 1.08883]` and clipping flag `true`. The exploratory notice must equal the fixed KLT Image notice.

### Replay

`ImagePipeline.replay(_:recipe:)` validates the complete recipe before processing and applies exactly:

```text
x       = frozen base conversion(target decoded pixel)
w       = frozen A × x + frozen b
wPrime  = frozen muW + frozen T × (w - frozen muW)
xPrime  = frozen AInverse × (wPrime - frozen b)
output  = frozen outputMapping(xPrime)
```

The replay loop shares the same affine application/output helpers used by the originating calculated branch and the current standard renderers. It uses the same left-to-right dot products, clamp, `.rounded()` premultiplication, alpha byte, cancellation stride, and `CGImage` creation. This shared frozen-application path is the exact-original replay guarantee.

Replay must not instantiate `RunningCovariance3`, call `makePlan`, scan target extrema, change the center, fit gamut/range, or calculate target covariance, correlation, eigensystem, gains, stable counts, or regions. Instrument these calls in tests so a replay fails if target-derived analysis occurs.

`ReplayDiagnostics` is target outcome metadata, not an adaptive input. During the one output pass, for pixels with nonzero alpha, count pixels having at least one pre-clamp encoded-sRGB component outside `[0,1]`; for Lab, the existing inverse conversion must expose its unclipped encoded value/mask before applying the same current clip. Record `evaluatedPixelCount`, `clippedColorPixelCount`, `clippedFraction`, `minimumMappedComponent`, `maximumMappedComponent`, and `mappedRange`. A nonzero count produces factual clipping guidance; `clippedFraction >= 0.01` produces the stronger “substantial clipping” guidance. A finite `mappedRange < 0.05` produces low-contrast guidance. A fully transparent target records zero evaluated/clipped pixels and null range values. Diagnostics never change bytes. Original-source equality is fingerprint **and** oriented dimensions; otherwise the result is labeled reuse on a different source.

## Local Method-Library Persistence

### Ownership and location

`MethodLibraryStore` is a Swift actor in `KLTImage`. It resolves the sandboxed user-domain Application Support URL and appends `com.kltimage.mac/MethodLibrary/library.json`. It owns all reads and mutations serially. `KLTCore` owns only the value types, validators, and store document codec; it does not know the URL or AppKit.

Curated definitions are compiled into `KLTCore` and merged for presentation after local load. Only user working spaces and saved recipes are stored. Source images, decoded bytes, enhanced bytes, regions, ordinary control choices, comparison state, analysis records/history, and security-scoped bookmarks are prohibited from the store.

### Store document version 1

```text
schema: "org.kltimage.method-library"
version: 1
userWorkingSpaces[]:
  libraryName, purpose|null, createdAt, modifiedAt
  definition: WorkingSpaceDefinitionV1
savedTransforms[]:
  libraryName, createdAt, modifiedAt
  recipe: TransformRecipeV1
```

Store timestamps are UTC RFC 3339 with exactly three fractional digits. They are library metadata and are stripped from portable interchange. Arrays are sorted by stable identifier before encoding so test fixtures are deterministic. Identifiers must be unique across each artifact type; normalized names must be unique within each user section. Working-space and recipe namespaces remain separate.

Name conflict normalization is: trim Unicode whitespace/newlines, apply canonical precomposition, then locale-independent lowercase using `en_US_POSIX`. Preserve the validated trimmed display spelling. Do not transliterate or remove diacritics.

### Load, transaction, and atomic replacement

- Missing file means an empty user library and is not an error or migration. Do not create a file until the first successful mutation.
- Read at most 16 MiB for the application-managed store, which bounds corruption while accommodating the required 500-item fixture; decode the entire supported document, validate every item and cross-item invariant, then publish one immutable snapshot.
- Corrupt, internally inconsistent, or future-version content publishes no user item, is not overwritten, and leaves curated/standard analysis usable. Surface one recoverable library error.
- A mutation copies the full in-memory document, applies the proposed change, validates the full result, encodes it, atomically persists it, and only then publishes the new snapshot. Failed persistence leaves both the actor snapshot and file at the prior revision.
- Perform atomic replacement in the same directory: create a random exclusive mode-`0600` temporary file with no symlink following, write all bytes, `fsync` the file, close it, atomically rename over `library.json`, then `fsync` the directory. Remove only the known temporary file on failure. Never truncate the current store in place.

There is no legacy persistent source to import. `MethodLibraryDocumentV1` is the initial schema. Implement a migration registry keyed by integer store version so future steps are `Vn DTO -> Vn+1 DTO`, pure, deterministic, fully validated, and atomically committed only after the final version succeeds. Version 0/missing is empty-without-write; versions greater than current fail closed. Golden fixtures cover missing, v1, malformed v1, and future version. No migration reads `UserDefaults` or prior analysis JSON.

## Portable Interchange

### Shared working-space DTO

`WorkingSpaceDefinitionV1` has exactly these fields:

```text
identity: { kind, identifier }
definitionVersion
base
baseChannelOrder[3]
baseChannelUnits[3]
workingChannelNames[3]
forwardMatrix[9]
offset[3]
inverseMatrix[9]
outputBehavior
```

For `.klt-space.json`, `identity.kind` must be `user`; curated definitions become exportable only after Duplicate creates a new user UUID/version 1. For recipe snapshots, identity may be `standard`, `curated`, or `user`, with the exact allowlist/UUID rules above.

### Working-space document version 1

```text
schema: "org.kltimage.working-space"
version: 1
libraryName
purpose: string|null
definition: WorkingSpaceDefinitionV1
```

Suggested suffix: `.klt-space.json`.

### Transform-recipe document version 1

```text
schema: "org.kltimage.transform-recipe"
version: 1
libraryName
recipe:
  identifier                       // lowercase UUID
  recipeFormatVersion              // 1
  algorithm: { identifier, version }
  workingSpaceNameAtCapture
  workingSpace: WorkingSpaceDefinitionV1
  originSource:
    filename, width, height, analysisPixelFormat
    fingerprint: { algorithm, value }
  originatingAnalysis:
    matrixMode, samplingMode, samplePixelCount
    region: null | { normalized, sourcePixels }
  frozenApplication:
    workingCenter[3]
    transform[9]
    outputMapping:
      { kind: "encoded-srgb-global-range-v1", minimum, maximum, scale, clipsToUnitRange: true }
      | { kind: "cie-lab-d65-to-clipped-srgb-v1", referenceWhite[3], clipsFiniteOutOfGamutValues: true }
    matrixStorage: "row-major"
    alphaPolicy: "preserve-source-byte"
    byteQuantization: "clamp-unit-premultiply-round-nearest"
  interpretation: { exploratoryUseNotice }
```

Suggested suffix: `.klt-transform.json`. Renaming a recipe changes only the top-level `libraryName`; duplicating creates a new recipe UUID while retaining all frozen application/origin fields.

### Canonical encoder

Both documents use dedicated DTOs and the same canonical writer as analysis records: UTF-8, sorted keys, stable unlocalized enum strings, JSON round-trippable finite `Double` values, fixed row-major arrays, no timestamp, no absolute path, no bookmark, and exactly one final newline. Encoding the same immutable artifact twice must return identical bytes. Export writes through the user-selected security-scoped destination with the same durable atomic replacement primitive; cancel creates nothing and failure leaves no final partial file.

### Strict importer

Import first obtains the security scope, checks that the selected item is a regular file, then reads at most `262_145` bytes and rejects if more than `262_144` bytes are present. Do not map an arbitrarily large file before enforcing the limit.

Use a bounded RFC 8259 parser (or a duplicate-key-preserving token prepass plus decoder), not `JSONDecoder` alone. Enforce maximum nesting depth 16, reject invalid UTF-8/BOM, duplicate object keys, trailing non-whitespace, invalid number grammar, non-finite conversion, unknown fields, and overlong strings/arrays before DTO construction. The schema/type and exact supported version are checked before semantic mapping. No field is evaluated as a path, URL, code, expression, type name, selector, plug-in, shader, file reference, or network location.

Parsing and semantic validation produce an immutable `PendingMethodImport` in memory. No source/workspace/library state changes before the user confirms. On identifier or normalized-name conflict, Replace, Import as Copy, and Cancel are explicit:

- Replace may replace only the same artifact type and never a standard/curated item. A same user identity/version with different mathematical bytes is rejected as inconsistent; changed mathematics must carry a higher definition version or be imported as a new copy.
- Import as Copy creates a new UUID; a working-space copy starts at definition version 1; the user resolves any remaining name conflict before commit.
- Cancel discards the pending value.

Commit is one full-library actor transaction. Any failure adds, replaces, or deletes nothing and does not touch the current source, execution selection, result, record, or export availability. Both importers reject `org.kltimage.analysis-record` before inspecting overlapping nested fields.

## Analysis-Record Evolution

### Version 1 is frozen

Do not edit `KLTAnalysisDocumentV1`, `AnalysisRecordJSONEncoder`, its schema/version constants, enum strings, key structure, formatting, source fingerprint, or golden fixtures. Standard RGB/Lab **calculated** results continue to produce `org.kltimage.analysis-record` version 1 byte-for-byte. In that frozen schema, calculated mode is implicit in the document's existing target-derived statistics; the in-app inspector may label it Calculated without adding JSON bytes.

Add a routing wrapper rather than changing the v1 type:

```swift
public enum AnalysisRecordSnapshot: Equatable, Sendable {
    case legacyV1(AnalysisRecord)
    case extendedV2(ExtendedAnalysisRecord)
}
```

Custom/curated affine calculations and every replay use version 2.

### Analysis document version 2

Version 2 retains the schema identifier `org.kltimage.analysis-record` and uses `version: 2`. It is a documentary DTO with a tagged execution payload:

```text
schema, version
targetSource:
  filename, width, height, analysisPixelFormat, fingerprint
execution:
  mode: "calculated" | "replayed"
  algorithm: { identifier, version }
  workingSpaceNameAtExecution
  workingSpace: WorkingSpaceDefinitionV1
conventions:
  baseChannelOrder[3], baseChannelUnits[3], workingChannelOrder[3]
  matrixStorage: "row-major", regionOrigin: "top-left", regionBounds: "half-open"
calculation: null | {
  matrixMode, samplingMode, region
  samplePixelCount, workingMean[3], covariance[9], analysisMatrix[9]
  eigenvalues[3], eigenvectors[9], workingTransform[9]
  stableVariableCount, stableComponentCount, outputMapping
}
replay: null | {
  recipe: { identifier, recipeFormatVersion, libraryNameAtExecution }
  originSource
  originatingAnalysis
  frozenApplication
  targetOutcome: {
    sameAsOrigin, evaluatedPixelCount, clippedColorPixelCount, clippedFraction,
    minimumMappedComponent, maximumMappedComponent, mappedRange
  }
}
interpretation:
  limitedVariation
  exploratoryUseNotice
```

Exactly one of `calculation` and `replay` is non-null and must agree with `execution.mode`. A calculated record contains target-derived statistics exactly once. A replay record contains no target covariance, mean, eigensystem, gains, or sample region; its origin and frozen application are explicitly nested under replay so they cannot be mistaken for target analysis. `targetOutcome` is observational and does not alter the recipe or output.

The in-app inspector and exporter consume the same accepted `AnalysisRecordSnapshot`. They distinguish stable identity/version, captured label, and current library status (“renamed” or “no longer in library”) without mutating the snapshot.

## App-Owned State and Concurrency

### Library state

`@MainActor @Observable MethodLibraryModel` presents immutable snapshots returned by `MethodLibraryStore`. It owns library loading/error state, editor drafts, import preview/conflict state, and library-operation announcements. It does not own source pixels or processing requests. Standard and curated definitions are available immediately; a corrupt/future user store disables user-library mutations until an explicit recovery action but never blocks standard RGB/Lab analysis.

Persistence tasks have their own operation IDs/tasks. They must not reuse `WorkspaceModel.activeOperation`, because saving/renaming/importing a library artifact must not accidentally cancel image calculation/export or let an old library callback publish over a newer transaction.

### Workspace method state

`WorkspaceModel` owns only transient execution state:

```swift
enum WorkspaceMethodSelection: Equatable, Sendable {
    case calculated(WorkingSpaceRevision)
    case replayed(TransformRecipeSnapshot)
}

struct LastCalculatedControls: Equatable, Sendable {
    var workingSpace: WorkingSpaceRevision
    var matrixMode: AnalysisMatrixMode
    var sampleSource: AnalysisSampleSource
    var region: SourcePixelRegion?
}

struct AnalysisRequestKey: Equatable, Hashable, Sendable {
    let source: SourceIdentity
    let execution: EnhancementExecutionRequest
}

struct CompletedEnhancement: @unchecked Sendable {
    let key: AnalysisRequestKey
    let jobID: UUID
    let value: EnhancedImage
    let appliedMethod: AppliedMethodSnapshot
    let record: AnalysisRecordSnapshot
}
```

Calculated mode preserves the current matrix/sampling/region rules. Replayed mode disables those controls because they are not request inputs. “Calculate for This Image” restores `LastCalculatedControls` for the current session, creates a calculated request, and leaves the recipe/library unchanged.

Selecting a working space, selecting a recipe, switching mode, committing a mathematical edit to the selected space, or replacing source cancels/supersedes the active job and changes the request key before launching new work. A late success/failure/cancellation cannot alter the new request. Method/status text while processing comes from the request snapshot; ready text, Save eligibility, inspector, and exports come from the accepted completed snapshot.

Renaming a selected working space/recipe changes library presentation only; it neither changes the request key nor relabels an already accepted snapshot. Deleting the selected user working space is confirm-first, persists deletion, then selects standard RGB and recalculates from the unchanged source. Deleting a recipe does not alter an already current replayed result; its captured snapshot remains current and is labeled no longer in library until the user selects/captures another method. Saved recipes are unaffected by edit/delete of their originating space.

Applying a recipe to another image routes through the existing confirmed open/replace flow with a pending immutable recipe snapshot. Cancel retains the prior source/result. Successful decode creates a fresh source generation and launches replay with the pending recipe. An ordinary unrelated Open Image keeps current shipped calculated-control retention behavior and does not silently auto-apply a recipe.

### Save Transform transaction

The Save action first captures a `TransformRecipeSnapshot` from `currentCompletedEnhancement` synchronously on the main actor, then asks for a name, then persists that immutable seed through the library actor. Later control/source changes cannot change the saved bytes. Store failure adds no item and does not change the result. A replayed, stale, processing, failed, canceled, degenerate, or partially limited-variation result exposes no Save action.

## Module and File Boundaries

### `KLTCore` additions

- `WorkingSpace.swift`: identities, bases, revisions, curated catalog, draft/validation issues, affine application.
- `TransformRecipe.swift`: recipe/origin/frozen-output values, capture validator, replay diagnostics.
- `MethodDocuments.swift`: dedicated v1 portable DTOs, canonical codecs, strict bounded JSON parsing/mapping.
- `MethodLibraryDocument.swift`: versioned store DTOs, whole-library validation, pure migration registry.
- `ExtendedAnalysisRecord.swift`: version-2 runtime record and export DTO/encoder; no edits to the v1 DTO/encoder contract.

### `KLTCore` modifications

- `Matrix3x3.swift`: add `Hashable`, safe checked construction, determinant, deterministic inverse, infinity norm, and residual helpers. Keep current multiplication order.
- `AnalysisTypes.swift`: add the tagged working-space/execution contracts while retaining standard compatibility initializers and raw values.
- `DecorrelationStretch.swift`: expose one immutable frozen plan/application value sufficient for direct capture; do not change plan construction constants or eigensystem ordering.
- `ImagePipeline.swift`: retain both shipped standard calculation branches; add affine calculation and replay entry points using shared frozen render/output helpers; return applied-method snapshot and diagnostics with pixels.
- `AnalysisRecord.swift`: leave v1 encoding code behaviorally untouched. Only add bridging/routing outside the v1 DTO if necessary.

`KLTCore` remains free of SwiftUI, AppKit panels, Application Support URLs, and observable state.

### `KLTImage` additions/modifications

- Add `MethodLibraryStore.swift` for actor isolation, Application Support path resolution, durable atomic writes, and security-scoped portable read/write orchestration.
- Add `MethodLibraryModel.swift` for main-actor presentation state and transactional commands.
- Add method library, working-space editor/detail, recipe detail, import preview, and conflict views using native SwiftUI controls.
- Extend `WorkspaceModel.swift` with explicit calculated/replayed selection, separate last-calculated controls, recipe application, full request currency, capture/save hooks, and versioned record presentation.
- Extend `AnalysisControlsView.swift`, `MetadataStrip.swift`, `AnalysisRecordView.swift`, and `ContentView.swift` to display method type/identity and route actions; views never calculate matrices, parse JSON, or perform persistence.
- Continue generating the Xcode project from `project.yml`; its source directory declarations already include new Swift files.

There is no API endpoint, repository, ORM, Core Data/SwiftData model, `UserDefaults`, `@AppStorage`, `SceneStorage`, cloud container, or network client.

## Additive Changes to Existing State

The following shipped state changes are intentional and additive:

- `AnalysisMethod.colorSpace` selection becomes a standard-space compatibility view over a broader immutable working-space selection. The `rgb`/`lab` identifiers and baseline initializer remain stable.
- `AnalysisRequestKey.input` becomes a tagged calculated/replayed execution snapshot. Source generation and job-ID acceptance remain unchanged.
- Existing immutable source/region descriptors may add `Hashable` conformance where required by the new request values; hashing adds no serialization or behavior change. Display filename/library metadata remains excluded from scientific request identity.
- `EnhancedImage`/`CompletedEnhancement` gain an immutable applied-method snapshot, replay diagnostics when applicable, and a version-routed record snapshot.
- `StretchAnalysis.mean` is explicitly the working-space center for affine methods; standard RGB/Lab meaning is unchanged.
- `StretchOutputMapping` gains versioned generic base-output records only for new branches. Existing v1 mapping cases and their JSON spelling remain unchanged.
- `WorkspaceModel` gains library selection/replay state but does not gain cross-launch source, result, region, or control restoration.
- Application Support persistence is introduced only for user method artifacts. This supersedes the prior blanket “no application-support file” constraint solely for the method library; all prior prohibitions on image/history/project persistence remain.

## Failure, Security, and Privacy Boundaries

- Invalid definitions/recipes fail before a processing job is launched. There is never silent RGB/Lab/prior-method fallback.
- Every pixel intermediate must remain finite. Failure publishes neither partial pixels nor a record.
- Import and store documents are inert data. There is no evaluation, dynamic lookup, polymorphic class decoding, plug-in loading, path traversal, external entity, network access, or bookmark creation.
- File-panel security scope lasts only for the bounded read or explicit write and is always released with `defer`.
- Store corruption is fail-closed and non-destructive. Ordinary standard analysis remains available.
- Recipe target mismatch, clipping, low contrast, or an unhelpful result never adapts frozen values. Guidance offers calculated mode as a separate action.
- All content and persistence remain local. No pixels, fingerprints, filenames, methods, or usage data leave the Mac.

## Verification Fixtures and Engineer Handoff

The Engineer must preserve all existing Debug/Release golden tests and add the following independent seams:

- Curated forward/inverse/condition fixtures above, plus equivalent imported-user-definition pixel equality.
- Exact validator boundary and typed-error fixtures for count, string, finite, coefficient, offset, determinant, inverse, condition, convention, version, and identity failures.
- A hand-computed affine pixel fixture that pins `x -> w -> wPrime -> xPrime -> output` operation order for both bases.
- Every curated/user × covariance/correlation × whole/region combination, including transparent, selected-region degenerate, partial stability, cancellation, stale job, 64 MP, and output-export regression cases.
- Capture/replay golden tests for standard RGB, standard Lab, each curated space, and a custom offset space. Replay on the original decoded source must match the originating premultiplied RGBA `Data` byte-for-byte.
- Instrumented cross-source replay proving no accumulator, plan, extrema scan, eigensolver, or target range/gamut fit is called; pin clipping diagnostics without changing pixels.
- Version-1 analysis JSON fixtures and SHA-256 hashes unchanged; version-2 calculated/replayed schema and golden-byte fixtures added separately.
- Canonical `.klt-space.json`/`.klt-transform.json` repeated-export hashes, full round trips, wrong-schema rejection, duplicate keys at every nesting level, trailing payload, invalid UTF-8/BOM, deep nesting, oversized input at 256 KiB + 1, non-finite/extreme numbers, inconsistent inverse/output mapping, and analysis-record rejection.
- Store fixtures for absent, valid v1 with 500 items, corrupt/truncated/inconsistent, future version, and every atomic-write interruption boundary. A failed mutation must leave the previous bytes readable.
- Main-actor tests for rename without recalculation, mathematical edit with recalculation, active-space deletion to RGB, recipe deletion retaining current replay, import conflict choices, immutable Save capture during control mutation, and calculated/replayed request supersession.
- Release benchmarks: 24 MP affine calculation and replay each under five seconds on supported Apple Silicon; 500-item library load under one second; no avoidable second full-resolution replay buffer.
- UI/VoiceOver/keyboard coverage for separate artifact sections, equations, validation, import conflicts, captured-versus-current labels, mode distinction, frozen controls, clipping guidance, and Calculate for This Image.

Implementation is complete only when the persistent library, interchange documents, analysis v2, UI inspector, and pixel renderer all consume the same validated immutable snapshots, while standard calculated pixels and version-1 analysis bytes remain unchanged.
