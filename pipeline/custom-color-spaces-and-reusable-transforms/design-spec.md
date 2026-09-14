# Design Spec — Custom Color Spaces and Reusable Transforms

## Visual Direction

Custom Color Spaces and Reusable Transforms extends KLT Image’s established scientific-instrument interface without changing its visual language or workspace hierarchy. IBM Plex typography, fixed-light blue-green neutrals, one restrained teal active-state color, cool one-pixel dividers, and shallow navy-tinted depth keep the photograph—not the method library—the normal focal point.

The feature introduces more method density, so type and provenance carry more of the distinction than decoration. A working space is consistently described as something that calculates a new transform; a saved transform is consistently described as a frozen recipe that replays accepted values. Calculated and replayed results are never distinguished by color alone.

The method library becomes the focal utility surface only while it is open. It is one continuous, trigger-anchored sheet with a navigation column and detail column, not a dashboard or a collection of nested cards. Technical matrices use aligned IBM Plex Mono values, narrow leading rules, and light horizontal washes already established by the analysis-record surface.

## Screens / Views

### Loaded Image Workspace

Retain the shipped four-part composition: compact title bar, comparison toolbar, left analysis rail plus image canvas, and bottom metadata strip.

- Keep `KLT Image` and the source filename centered in the title bar.
- Add an outlined `Methods` action beside Open Image or the existing title-bar utility actions. It opens the method library and is available even when no image is open.
- Keep `Export Result` as the sole filled teal action in the loaded main workspace.
- Add a compact execution badge to the toolbar: `CALCULATED` or `REPLAYED`. Pair it with text naming the working space or recipe so the distinction does not depend on color.
- Replace the previous three-option comparison selector with four display modes: `Original`, `Side-by-Side`, `Slider`, and `Processed`.
- Keep synchronized zoom at the trailing edge. Pan and fit state remain shared by every visible pane.
- Keep the analysis rail continuous, divided by one-point rules. Do not place each control group in a card.
- Keep the bottom interpretation guidance visible. It must mention that coordinate choice and fixed reuse can amplify noise, compression, lighting differences, clipping, or gamut loss.

The approved prototype demonstrates `Luma + Chroma`, correlation, and selected-region sampling on `western-gull-wing-02.tif`. This is realistic design content, not a changed application launch default. RGB, covariance, and whole-image calculation remain the compatibility baseline.

### Comparison Canvas and Four Display Modes

The comparison selector changes presentation only. It must not create a new `EnhancementExecutionRequest`, cancel processing, recalculate statistics, change a recipe, invalidate a current result, or alter image-export pixels. When a user selects a mode, announce: `[Mode] view selected. Scientific result unchanged.`

`Side-by-Side` is the default loaded comparison mode and preserves the established split-workspace behavior.

#### Original

- Show one full-width pane containing the immutable decoded source.
- Keep source-coordinate sample overlays available when selected-region calculation is active.
- Hide result-only clipping guidance from the canvas because the processed pixels are not visible; clipping remains available in provenance.
- Label the pane `Original`.

#### Side-by-Side

- Show two simultaneously visible panes with equal visual weight and one crisp one-point divider.
- The leading pane contains the immutable source; the trailing pane contains the current processed result.
- Both panes use the same zoom and pan state, preserve the same image aspect ratio, and mirror any canonical sample-region overlay.
- Labels read `Original` and `Processed · calculated` or `Processed · replayed`.
- A compact canvas-level status reads `Synchronized panes · display only · no recalculation`.
- Direct region manipulation, when applicable, remains on the source pane; the processed overlay is informational.

#### Slider

- Show the original and processed pixels registered over one canvas.
- A vertical reveal divider starts at 50 percent, with original pixels to the leading side and processed pixels to the trailing side.
- Dragging the divider follows the pointer immediately. Do not interpolate or snap during the gesture.
- Expose the divider as a horizontal accessibility slider named `Comparison reveal position` with values such as `42% original, 58% processed`.
- Left/Down Arrow moves the divider 2 percentage points toward the leading edge; Right/Up Arrow moves it 2 points toward the trailing edge. Shift plus an arrow moves 10 points. Home selects 0 percent; End selects 100 percent.
- Keep visible `Original` and `Processed · calculated/replayed` labels at opposing top corners.
- A compact canvas-level status reads `Drag divider or use arrow keys · display only · no recalculation`.

#### Processed

- Show one full-width pane containing the accepted processed result.
- Use the user-facing term `Processed` in the comparison control and pane label. Existing internal types may retain names such as `EnhancedImage`; internal naming must not leak into this control.
- The pane label includes execution state: `Processed · calculated` or `Processed · replayed`.
- Show applicable replay clipping or low-contrast guidance over this view.

Zoom, pan, and fit behavior are shared across all four modes and survive mode changes. Zoom actions update every source/result viewport in lockstep, including both Side-by-Side panes and both Slider layers. The mockup’s zoom range is 50–200 percent in 25-point steps; production should retain the shipped zoom increments if they differ, provided all panes remain synchronized.

### Calculated Analysis Rail

Calculated mode retains matrix and sampling controls and replaces the fixed RGB/Lab selector with one working-space picker.

- Heading: `Analysis controls` with `Choose the coordinates and pixels that calculate a new transform.`
- Working-space picker: show the current name, artifact kind, base, and mathematical definition version. The supporting label `CALCULATES` reinforces the execution path.
- Supporting copy: `The working space changes the three variables used to calculate this image’s transform.`
- Matrix mode: retain Covariance and Correlation with current semantics.
- Statistical sample: retain Whole image and Selected region, current region validation, and the statement that the full image receives the transform.
- `Save Calculated Transform` is a secondary action below the calculation controls.
- The compact rail summary names the working space and says `calculated here`.

Changing a working space, matrix mode, sample mode, committed region, or mathematical definition creates a new calculated request and immediately makes a mismatched completed result stale. Renaming only a library label does not recalculate or relabel an already accepted result.

`Save Calculated Transform` is available only for an accepted, current, successful, non-limited-variation calculated result. It is unavailable while processing, awaiting a region, failed, stale, canceled, identity/degenerate, partially limited, or replayed.

### Replayed Analysis Rail

Replayed mode replaces active calculation controls with a frozen-method summary.

- Heading copy changes to `Inspect the frozen method or return to image-specific calculation.`
- Show the recipe name, origin filename, and a `FROZEN` label.
- State: `No values are recalculated from this target.`
- Keep originating matrix and sampling values visually inactive and label them `INACTIVE`; they are provenance, not target controls.
- Provide an outlined `Choose Another Recipe` action.
- Provide `Calculate for This Image`, which restores the session’s last calculated controls and starts a new calculated request from the unchanged source.
- The rail summary reads `[Recipe name] · replayed unchanged`, followed by factual target diagnostics such as `No target statistics · 12.8% clipped · local only`.

Replayed mode must never make a disabled control look merely unavailable without explanation. The frozen summary and return route appear in the same reading order as the replaced controls.

### Method Library Surface

Open the library as a focused utility sheet above the workspace with a restrained scrim. At ordinary desktop sizes, target approximately 1010 points wide and at most 720 points tall, while maintaining at least 24 points of window clearance.

The header contains:

- `Method library`
- `Working spaces calculate a new transform. Saved transforms replay one accepted calculation unchanged.`
- An outlined `Import…` action.
- One close button with an accessible name.

The body uses a navigation column and detail column separated by one cool divider. The navigation begins with two explicit tabs:

1. `Working Spaces`
2. `Saved Transforms`

The tabs are mutually exclusive, expose selected state, and use the same light raised selection treatment as existing KLT Image tab and segmented controls. Arrow-key tab navigation may be used in addition to ordinary Tab navigation.

Opening the library moves focus to the close button or first logical control. Escape or the close button dismisses it and restores focus to `Methods`. Library browsing must not change the current workspace until the user invokes an explicit Use or Apply action.

### Working-Space Library

The Working Spaces navigation is divided into three structural groups, not visual cards:

- `STANDARD`: RGB and CIE Lab D65.
- `CURATED`: Luma + Chroma, Red + Complement, and Lab Blue–Yellow.
- `MY SPACES`: user-created and imported definitions.

Each row displays name, base/purpose shorthand, definition version, and artifact kind. The selected row uses `accentSoft`, a one-point accent-tinted boundary, strong text, and explicit selected semantics. Built-in status confers no rank or scientific authority.

The detail view contains:

- Name and factual purpose.
- Tags for Standard/Curated/Custom, base, and definition version.
- Stable identity and current-library status when relevant.
- The exact formula `working = A × base + b`.
- Three channel names, forward 3 × 3 row-major matrix, offset vector, derived inverse, condition number, base conventions, and output behavior.
- A calm note that the space changes exploratory coordinates and does not rank, detect, or prove a biological feature.

Actions vary by kind:

- Standard and curated spaces: Inspect, Duplicate to editable user copy, and Use for Calculation. They cannot be renamed, edited in place, deleted, replaced, or exported as user definitions before duplication.
- User spaces: Rename, Duplicate, Edit, Export Definition, Delete, and Use for Calculation.

`Use for Calculation` is the one filled action in the open working-space detail. It closes the library, selects the immutable revision, and starts a calculated request if a source is open. With no source, it sets the calculation selection without opening an image automatically.

Deleting an active user working space requires confirmation that saved recipes remain independent. After a successful persisted delete, select RGB and recalculate from the unchanged source. Cancel changes nothing.

### Working-Space Affine Editor

The editor replaces the library detail column while retaining the navigation context. A back control returns to the selected working-space detail without committing invalid drafts.

Fields appear in this order:

1. Library name, 1–80 Unicode scalar values after trimming.
2. Optional purpose, no more than 500 Unicode scalar values when exposed.
3. Base selector: `Encoded sRGB` or `CIE Lab D65`.
4. Three non-empty channel names, each no more than 40 Unicode scalar values.
5. Exactly nine decimal forward coefficients in a visible 3 × 3 grid.
6. Exactly three decimal affine offsets.

Bind numeric fields to draft strings so empty, partial, signed, overlong, non-finite, or otherwise invalid input remains visible for correction. Accept decimal values only. Do not provide an expression parser or accept functions, scripts, shader code, file references, additional channels, or executable content.

The grid header names the fixed base channels. Encoded sRGB uses Red, Green, and Blue. CIE Lab D65 uses L*, a*, and b*. Rows are the user-named working channels. Offsets occupy a final clearly separated column.

Validate continuously and again on commit. The feedback region directly below the grid shows one state at a time:

- Valid: success leading rule and `Definition is reversible`, plus derived condition number.
- Invalid: warning leading rule, warm tint, and the first specific failed rule. Examples include wrong count, non-finite number, coefficient outside ±100, offset outside ±10,000, singular matrix, inverse term outside ±1,000, or condition number above 1,000.

No invalid definition starts processing or enters the library. Disable Save while invalid, connect invalid fields to the explanation for VoiceOver, and never normalize, clamp, repair, or silently substitute RGB/Lab.

Creating or duplicating saves version 1 under a new user UUID. Committing a mathematical edit creates the next immutable definition version. Renaming changes library metadata only. Prior records and recipe snapshots retain their captured revision.

### Saved-Transform Library

Saved Transforms is a separate library tab and list. Never call both artifact types presets.

Each row displays recipe name, captured working-space name/version, and last-modified date. The detail view presents:

- Recipe name and format version.
- Origin filename, oriented dimensions, and shortened fingerprint with the full value available to accessibility/copy.
- Captured working-space identity and full definition snapshot.
- Originating covariance/correlation, sampling mode, optional region, and sample count as provenance.
- Frozen working center, final 3 × 3 transform, inverse mapping, output mapping, algorithm version, alpha policy, and byte quantization.
- A warning that fixed reuse can amplify noise, compression, lighting mismatch, clipping, or poor contrast.

Actions are Rename, Duplicate, Export Recipe, Delete, Apply to Current Image, and Apply to Another Image. `Apply to Current Image` is the one filled action in recipe detail when a source is loaded. Applying to another image uses the existing confirmed open/replace workflow and retains an immutable pending recipe only after the new source is accepted.

Applying a recipe starts replay with the frozen snapshot. It does not calculate target covariance, correlation, mean, eigensystem, gains, range, gamut fit, or sampling region.

### Save Calculated Transform

Open a compact modal titled `Save calculated transform` from an eligible current calculated result.

- Supporting copy: `Freeze the exact accepted calculation for deterministic replay.`
- Require a non-empty recipe name of no more than 80 Unicode scalar values.
- Show a read-only summary of working-space name/version, source filename, matrix and sampling modes, and `center · transform · inverse · output mapping`.
- Capture the immutable recipe seed before presenting or committing the dialog. Later source/control changes cannot alter the bytes being saved.
- Use Cancel and one filled `Save Transform` action.
- On success, add the recipe to Saved Transforms and announce its name. Keep the current result unchanged.
- On persistence failure, add nothing and report that the prior library and displayed result remain unchanged.

### Calculated and Replayed Result Provenance

The toolbar badge, processed-pane label, rail summary, metadata cluster, and provenance surface all identify execution mode in words.

For a calculated result, provenance states:

- `Calculated from this image`
- Target source identity.
- Working-space name, kind, stable identity, and definition version.
- Matrix mode, sampling mode, optional region, and sample count.
- That a new center, eigensystem, transform, and output mapping were derived from the target.

For a replayed result, provenance states:

- `Replayed unchanged` and `different source` or `same as origin`.
- Recipe name, identity, and recipe format version.
- Target source and originating source as separate groups.
- Frozen working-space definition and originating analysis.
- That the target supplied no statistics, center, eigensystem, range fit, or gamut fit.
- Target-only replay diagnostics, clearly labeled observational rather than adaptive.

The provenance trigger is outlined and right-aligned in the metadata strip. Its popover is a compact utility surface using the established 12-point radius and navy-tinted shadow. Escape closes it and restores focus to the trigger. It consumes the same immutable accepted `AnalysisRecordSnapshot` used for export; it never reconstructs data from live controls or mutable library labels.

### Replay Clipping and Low-Contrast Guidance

Replay diagnostics never alter processed pixels. Present them factually when the accepted replay completes.

- Any nonzero clipped-color pixel count may show `Some target colors clip under this frozen recipe.`
- At or above the specified substantial threshold of 1 percent, show the percentage, for example `12.8% of target pixels clip under this frozen recipe.`
- When mapped range is below 0.05, show low-contrast guidance.
- Explain: `The output is unchanged and may overemphasize lighting differences.`
- Offer `Calculate Instead` or `Calculate for This Image` as a separate action.
- Never use wording that suggests the recipe was corrected, adapted, optimized, or fitted to the target.

Place concise guidance at the lower edge of Side-by-Side, Slider, and Processed views without hiding the primary subject. Hide the canvas notice in Original view, but keep the diagnostic in provenance and the replay rail summary.

Choosing Calculate restores the session’s last calculated working space, matrix mode, sample mode, and valid region, leaves the recipe unchanged in the library, and calculates from the unchanged decoded target.

### Import Validation, Conflict, and Error States

`Import…` opens the standard sandboxed Mac file picker. After a selection, validate the entire bounded file in memory before presenting a preview. The preview is an inert confirmation surface; nothing is applied or persisted yet.

For a valid document, show:

- Filename and exact artifact type: Working Space or Saved Transform.
- Document schema and version.
- Display name and mathematical/recipe version.
- Base or origin summary.
- Definition value counts, inverse residual, and condition number for a working space.
- Frozen method and origin identity for a recipe.
- A statement that the current source, result, record, and controls remain unchanged.

If no conflict exists, the filled action reads `Import Working Space` or `Import Saved Transform`.

If a stable identifier or normalized-name conflict exists, replace the normal confirmation with an explicit comparison of incoming and local type/name/version and these choices:

1. `Replace` — only for the same user artifact type and never for standard/curated content.
2. `Import as Copy` — create a new UUID; a copied working space begins at definition version 1.
3. `Cancel` — discard the pending value.

Do not preselect Replace. A same-identity/same-version document with different mathematical bytes is an error, not a replace candidate. Cross-type replacement is never offered.

For a rejected document, show the exact first failure in a warm validation block and no enabled import action. Examples include file over 256 KiB, wrong artifact type, unsupported version, duplicate or unknown field, trailing payload, invalid UTF-8, wrong array length, non-finite/out-of-bound number, singular or ill-conditioned definition, inconsistent inverse, invalid frozen output mapping, or an analysis-record schema presented to a method importer.

Rejected, canceled, or failed imports add, replace, or delete nothing and leave source, method, result, record, and export availability unchanged. Copy should explicitly state `Nothing was imported, replaced, or applied.`

### Library Load and Persistence Errors

A missing method-library store is an ordinary empty user library: standard and curated spaces remain available, My Spaces and Saved Transforms show quiet empty states, and no file is written until the first mutation.

A corrupt, internally inconsistent, or future-version store fails closed. Show one recoverable library-level message without partially loading user artifacts or overwriting the file. Standard RGB/Lab and curated calculations remain available. Recovery actions must be explicit; opening the library must never silently reset the store.

Atomic-write failure leaves both the published library model and the prior on-disk file unchanged. Announce the failed action and retain the user’s current image work.

### Compact Window Behavior

At the supported minimum window width, preserve the analysis rail and image canvas before optional centered guidance. The four comparison labels must remain fully readable; if a segmented native control cannot fit, use an accessibility-equivalent compact toolbar menu that still exposes all four named modes and selected state. Do not abbreviate Side-by-Side to an unexplained icon.

The library sheet may reduce to available width with 20–24 points outer clearance. Keep its tabs, navigation, detail reading order, and bottom action row operable. At narrow widths, the detail column may replace the list after selection with a visible Back action rather than compressing matrices below readable size.

## Component Usage

- Build production surfaces in native SwiftUI. Retain AppKit only for existing open/save panels, security-scoped file access, and accessibility announcements.
- Extend the existing comparison-mode value to four presentation-only cases: Original, Side-by-Side, Slider, and Processed. Do not include comparison mode in `AnalysisRequestKey`.
- Use a native segmented `Picker` for the four comparison modes when all labels fit. Apply the explicit fixed-light styling already used by KLT Image so unselected labels remain readable under a dark system appearance.
- Reuse one shared viewport model for fit, zoom, and pan. Side-by-Side panes consume the same state; Slider layers use identical geometry in one clipped stack.
- Build Slider with two registered image layers, a clipped processed layer, and one draggable divider. Use a custom SwiftUI accessibility adjustable action if a native Slider cannot provide the required visual divider semantics.
- Continue using the existing comparison-image composition and sample-region transform. Never duplicate image-processing logic in a view.
- Use `SecondaryActionButtonStyle` for Methods, Save Calculated Transform, Choose Another Recipe, Calculate for This Image, Import, Export Definition, Export Recipe, Duplicate, Rename, and utility actions.
- Keep `PrimaryActionButtonStyle` exclusive to Export Result in the loaded workspace. Contextual sheets and confirmation dialogs may have one filled commit action because the underlying workspace is visually inactive.
- Present the method library with a native sheet or accessibility-equivalent window utility surface. Use one list/navigation region and one detail region; do not create nested card stacks.
- Implement Working Spaces and Saved Transforms as distinct enum-backed sections. Do not use one untyped preset collection.
- Bind editor coefficients, offsets, channel names, and name to draft strings. Views display `WorkingSpaceValidationIssue` values; they do not calculate determinants or inverses independently.
- Use reusable matrix/vector views with IBM Plex Mono, row-major labels, selectable text in detail views, and semantic row/column accessibility labels.
- Use native confirmation dialogs for active-definition deletion and import conflicts, but provide custom content where a side-by-side identity/version comparison is required.
- Use `NSSavePanel`/`NSOpenPanel` for explicit method export/import. Keep the bounded parser, validation, durable store mutation, and source processing outside SwiftUI views.
- Present Save Transform from a captured immutable `CompletedEnhancement` seed. The view receives eligibility and summary values from `WorkspaceModel`; it does not reconstruct the recipe.
- Extend the existing analysis-record/provenance presentation to route version 1 and version 2 snapshots without changing version-1 export layout or copy.
- Continue using `NSAccessibility.post` through the existing `statusAnnouncement` path. Coalesce superseded processing completions and do not announce obsolete results.
- Introduce no third-party UI, font, file-picker, matrix-editor, or motion dependency.

## Design Tokens Applied

- `inkStrong` `#142A36`: primary titles, item names, icons, matrix values, and selected controls.
- `ink` `#304854`: body copy, section headings, formulas, and high-value secondary labels.
- `inkMuted` `#667B84`: descriptions, provenance qualifiers, units, field bounds, and metadata.
- `navy` `#193A4A`: dominant structural tone and sheet/popover shadow tint.
- `accent` `#007F92`: active scientific selection, current processed-state dot, tab rule, and narrow matrix emphasis.
- `accentPressed` `#006C7D`: pressed/hover state and active labels.
- `accentSoft` `#D9F0F3`: selected library rows, working-space selector, validation information, and quiet active-state emphasis.
- `surface` `#F7F9F9`: window, navigation, footers, and continuous rail background.
- `surfaceRaised` `#FFFFFF`: sheet, popover, selected segment, inputs, and raised utility controls.
- `surfaceTint` `#EDF3F4`: toolbar, segmented-control bed, formula rows, and grouped utilities.
- `canvas` `#DBE3E5`: unchanged technical image-workspace background.
- `divider` `#9FB1B8` and `line` `#C9D4D8`: strong pane division, sheet boundary, and one-point internal structure.
- `success` `#18745F`: valid definition, accepted current state, and successful library mutation only.
- `warning` `#A35F15`: invalid definition/import, clipping, low contrast, store failure, and recoverable caution only.
- Warm warning surface `#FBF2E8`: a low-chroma support background for warning text; never use it as a large banner behind the image.
- IBM Plex Sans: 18–22 point sheet/detail titles, 11–15 point interface/body roles, and 10–11 point compact controls.
- IBM Plex Mono: 8–10 point status labels, artifact kinds, versions, filenames, fingerprints, formulas, vectors, matrices, bounds, and slider values.
- Spacing scale: 4, 8, 12, 16, 24, and 32 points. Rail sections use 13–16 points; utility-sheet detail regions use 18–20 points.
- Radius: 8 points for controls, rows, and inline guidance; 12 points for sheets, popovers, and confirmation surfaces; retain the existing 16-point preview/window treatment where applicable.
- Depth: one restrained navy-tinted shadow for the active utility surface and the existing light image shadow. No nested elevation.
- Technical canvas grid: low-contrast blue-green one-point grid at approximately 22-point intervals, subordinate to the photograph.

No new decorative palette, typography family, shape language, or elevation model is introduced. The feature extends the existing system with new semantic arrangements only.

## Interaction Notes

- Side-by-Side is the default loaded comparison mode. Original, Side-by-Side, Slider, and Processed are presentation state only and never trigger analysis or replay.
- Persist zoom and pan while switching comparison modes. When two panes/layers are visible, update them from one shared state so their source coordinates remain registered.
- The Slider divider follows pointer drag directly. Keyboard adjustment uses 2-point steps, 10 with Shift, and Home/End for extremes. Announce the resulting original/processed percentages without flooding VoiceOver during rapid pointer movement.
- Comparison mode, zoom, pan, library selection, sheet disclosure, popover disclosure, and matrix-detail scrolling are excluded from the scientific request key.
- Opening Methods, a working-space picker, or Choose Another Recipe does not change the current selection. Commit only from Use for Calculation or Apply.
- Switching from calculated to replayed mode immediately changes the immutable execution request, cancels/supersedes older work, disables calculated controls with an explanation, and labels any prior result stale until replay completes.
- Switching back with Calculate for This Image leaves the recipe intact, restores `LastCalculatedControls`, and starts a fresh calculation from the unchanged decoded source.
- Never expose Save Calculated Transform for a replay, stale result, limited-variation result, or pending calculation.
- Library rename changes presentation metadata only. Do not recalculate, change the request key, or rewrite an accepted result label.
- A mathematical working-space edit creates a new revision and recalculates only after a successful persisted commit when that space is active.
- Recipe application always uses the immutable recipe snapshot. Deleting or renaming its library item after replay begins does not change the current pixels or record.
- Applying a recipe to another image retains the recipe only after successful source replacement. Cancel leaves the prior source and result untouched.
- Replay clipping and range diagnostics are observational. Displaying or dismissing guidance never changes the recipe or pixels.
- Import parsing, semantic validation, conflict preview, and user confirmation complete before one atomic library transaction. No preview action changes the workspace.
- Escape dismisses the topmost import, save, provenance, or library surface and returns focus to its trigger. Do not let an underlying Escape handler close multiple layers at once.
- Tab order follows visual reading order: title actions, comparison modes, zoom, rail controls, canvas controls, metadata/provenance. Within the library: close/import, section tabs, rows, detail, footer actions.
- Each library row exposes artifact type, name, version/base or origin, and selected state to VoiceOver. Section headers expose counts but are not redundant focus targets.
- Every matrix value has row/column and channel context in its accessibility label. Visual alignment is not the only semantic representation.
- Invalid editor fields use an accessibility description tied to the specific validation issue. Preserve the attempted value and move focus only when the user explicitly invokes Save.
- Calculated/replayed, current/stale, valid/invalid, and clipped/not-clipped states use text and icons in addition to color.
- Fixed-light styling must be tested under macOS light and dark system appearances, increased contrast, larger text, keyboard-only use, VoiceOver, and Reduce Motion.
- The production UI uses current immutable data. Example filenames, matrices, clipping percentages, and dates in the prototype must not ship as placeholders.

## Motion Spec

- Comparison-mode selection: ease-out, 150 ms, selected segment center; near-instant opacity replacement under Reduce Motion; native SwiftUI animation.
- Original/Side-by-Side/Processed layout change: ease-out, 180 ms, canvas center; opacity-only direct replacement under Reduce Motion; SwiftUI transition.
- Slider reveal drag: no interpolation, easing, spring, or momentum; divider and mask follow the pointer immediately; identical under Reduce Motion; SwiftUI gesture update.
- Slider keyboard adjustment: ease-out, 150 ms, divider position; immediate geometry update under Reduce Motion; SwiftUI animation.
- Synchronized zoom: ease-out, 180 ms, shared pointer focal point or image center; immediate scale update under Reduce Motion; SwiftUI animation.
- Pan: no decorative easing during drag; panes track the pointer from shared viewport state; identical under Reduce Motion.
- Method-library presentation: ease-out, 180 ms, Methods trigger/window center; opacity-only near-instant presentation and no scale under Reduce Motion; native sheet transition.
- Library section or selected-item change: ease-out, 150 ms, selected row/detail top-leading edge; immediate content replacement under Reduce Motion; SwiftUI animation plus opacity transition.
- Working-space editor reveal: ease-out, 180 ms, detail top-leading edge; opacity-only immediate replacement under Reduce Motion; SwiftUI transition.
- Validation state change: ease-out, 150 ms, feedback top-leading edge; immediate text, rule, and color replacement under Reduce Motion; SwiftUI animation.
- Save/import confirmation surface: ease-out, 180 ms, invoking action; native no-scale/near-instant presentation under Reduce Motion; SwiftUI sheet/dialog transition.
- Provenance popover: ease-out, 170 ms, bottom metadata trigger; native opacity-only near-instant presentation under Reduce Motion.
- Accepted calculation/replay replacement: ease-out, 180 ms, processed pane center; direct image replacement under Reduce Motion; opacity transition only.
- Replay guidance: ease-out, 150 ms, canvas lower edge; immediate appearance/removal under Reduce Motion; opacity transition.
- Success confirmation: ease-out, 220 ms, bottom-center status origin; immediate appearance/removal under Reduce Motion.

Do not add spring, bounce, overshoot, pulse, blur entrances, decorative stagger, hover scaling, animated gradients, or motion to unchanged static content.

## Content Notes

Copy stays concise, factual, calm, and technically honest. Working-space choice and recipe reuse are exploratory methods, not claims of detection or scientific authority.

- Use `Working Space` for a coordinate definition and `Saved Transform` or `recipe` for a frozen transform. Do not use `preset` as a generic label for both.
- Use `Calculated` when the current image supplied statistics and a new transform.
- Use `Replayed` when a saved recipe supplied frozen values. Pair with `unchanged`, `same as origin`, or `different source` where applicable.
- Use `Processed` for the user-facing single-result comparison mode and processed pane. Keep `Export Result` as the existing export action.
- Use the exact comparison labels `Original`, `Side-by-Side`, `Slider`, and `Processed`.
- State `display only · no recalculation` beside comparison modes and announce `Scientific result unchanged` after a mode switch.
- Describe working spaces as changing `the variables used to calculate a new transform`.
- Describe saved transforms as applying `an earlier calculation unchanged` or `frozen values`.
- Curated purpose copy may say `separates`, `weights`, `gives an axis`, or `for exploratory comparison`. Never say `best`, `accurate`, `scientific`, `detects`, `reveals a true pigment`, or `proves`.
- Editor copy uses the exact bounded formula `working = A × base + b` and identifies matrices as 3 × 3, row-major.
- Validity copy says `Definition is reversible`. Invalid copy names the exact rule, such as `Forward matrix is singular.`
- Replay guidance says `The output is unchanged` and offers calculation as a separate action. Never say the recipe was fixed, corrected, normalized, optimized, or adapted.
- Preserve the persistent exploratory limitation: `Color differences are amplified for inspection. The result is not, by itself, a scientific measurement.` The expanded metadata guidance may also name noise, compression, lighting, clipping, color management, and gamut loss.
- Import success identifies one artifact and states that current work is unchanged. Import failure states `Nothing was imported, replaced, or applied.`
- Importers never call an analysis record a recipe, even when fields overlap. Prefer `This is an analysis record, not an executable method file.`
- Use complete filenames only where needed; fingerprints may be visually shortened in library rows but remain fully inspectable and copyable.
- Use `local only` and `Your images stay on this Mac` where privacy context is useful. Do not introduce cloud, account, gallery, or synchronization language.
- Errors identify the exact problem, what remained unchanged, and the next safe action. Avoid generic `Something went wrong` language.
