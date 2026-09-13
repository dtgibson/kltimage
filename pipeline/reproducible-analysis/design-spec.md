# Design Spec — Reproducible Analysis

## Visual Direction

Reproducible Analysis extends KLT Image's established scientific-instrument look without changing the workspace hierarchy. IBM Plex typography, blue-green tinted neutrals, a fixed light appearance, restrained depth, and teal state accents keep the image as the focal point while making dense numerical data readable and trustworthy.

The record appears as a trigger-anchored utility surface rather than a permanent inspector. It is precise and information-dense without becoming a dashboard, and it consistently frames the values as documentation of an exploratory transform rather than a scientific conclusion.

## Screens / Views

### Loaded Image Workspace

The shipped title bar, comparison toolbar, analysis rail, split image canvas, and metadata strip remain unchanged in structure. The loaded-state metadata strip gains one right-aligned record cluster:

- `ANALYSIS RECORD · CURRENT` appears in IBM Plex Mono with the success color when a record exactly matches the displayed result.
- Supporting copy reads `Source, settings, matrices, transform`.
- An outlined `Analysis Record` button with a document icon opens the record surface.
- The cluster is absent or disabled whenever no current record exists; it must never describe a stale result.
- `Export Result` remains the sole filled teal action in the main workspace.

The approved mockup uses a realistic Lab, correlation, selected-region analysis of `western-gull-wing.tif` at 6048 × 4024 pixels. This is demonstration content only; the shipped launch default remains RGB, covariance, and whole-image sampling.

### Analysis Record Popover

The Analysis Record opens above and visually anchored to its metadata-strip trigger. It uses a 12-point radius, one cool divider border, a restrained navy-tinted shadow, and a light raised surface. At normal desktop sizes it is approximately 620 points wide and never obscures the entire source-versus-result comparison.

The header contains:

- `Analysis record` as the display title.
- `The exact source, settings, and numerical transform behind this result.` as supporting copy.
- A compact success state: `CURRENT · MATCHES DISPLAYED RESULT`.
- One close button with an accessible name.

The body uses three tabs instead of nested cards:

1. `Summary`
2. `Matrices`
3. `Applied transform`

The selected tab uses strong ink and a two-point teal lower rule. Unselected tabs retain readable muted ink in both macOS appearance settings. Each panel scrolls independently when vertical space is constrained.

### Summary Tab

Summary is the opening tab and groups the record into three continuous sections separated by one-point dividers.

`Source identity` displays filename, oriented dimensions, analysis-pixel format, fingerprint algorithm, and the full lowercase hexadecimal fingerprint. Long fingerprints wrap in monospaced groups without truncation and remain selectable.

`Request` displays color space and basis, matrix mode, statistics source, sample count, integer source-pixel bounds, and normalized rectangle values. Whole-image records omit the region rows and state `wholeImage · full source population`.

`Conventions` displays channel order, channel units, row-major matrix storage, upper-left region origin, and half-open bounds. A warm, quiet guidance block states: `This record documents an exploratory enhancement. It does not establish a biological or scientific conclusion.`

### Matrices Tab

The Matrices tab presents the mathematical basis in reading order:

- Channel mean as a three-value monospaced vector.
- Covariance as a 3 × 3 row-major matrix.
- Analysis matrix as covariance or correlation, labeled by the active request.
- Eigenvalues in descending order.
- Eigenvectors as corresponding column vectors with deterministic signs.
- Stable-variable and stable-component counts.

Matrix rows use a subtle left teal rule and tinted horizontal wash, not individual cells or cards. Values align on decimal positions where practical and remain selectable. Section labels always repeat the channel order and units so the user never has to infer them from another tab.

### Applied Transform Tab

The Applied Transform tab shows the exact full-image transform, output mapping, and record-integrity rules.

- The transform appears as a 3 × 3 row-major matrix with the active channel order.
- The formula reads `transformed = mean + transform × (pixel − mean)`.
- RGB results show transformed minimum, maximum, uniform output scale, and clipping behavior.
- Lab results show `Lab → XYZ D65 → encoded sRGB`, finite gamut clipping to `[0, 1]`, and exact alpha preservation.
- Limited-variation results explicitly show the identity output path.
- Record integrity shows schema identifier, version, sorted-key ordering, finite and locale-independent numeric encoding, and the absence of file paths, timestamps, and job UUIDs.

### Export JSON

The popover footer keeps export secondary to the image workflow:

- Left copy says `Exported records are deterministic and local.` and previews the suggested `.klt-analysis.json` filename.
- An outlined `Export JSON` button opens a standard macOS save panel.
- No additional filled-accent button competes with `Export Result` in the main workspace.
- Cancel closes the save panel with no file and no toast.
- Success announces the exported filename through the existing accessibility status path.
- Failure keeps the current image and record intact and uses the established enhanced-pane or compact status error treatment.

### Currency States

The record action and popover derive from the same immutable accepted result snapshot as image export.

- Current: show the success label and enable inspection and JSON export.
- Processing, awaiting a region, invalid, failed, or stale: close an open record surface, remove its current label, and disable inspection/export until a matching result completes.
- Superseded completion: make no visible change and no accessibility announcement.
- New image: invalidate the prior record before decode begins.

The interface never presents previous record values beneath newly selected controls.

### Compact Window Behavior

At narrower supported widths, preserve the analysis rail and image canvas first. The persistent center interpretation sentence in the metadata strip may collapse before the record cluster. The record popover may reduce to the available window width with 20-point outer clearance, while retaining its header, tabs, independent scroll region, and footer actions.

## Component Usage

- Build the production interface in native SwiftUI and retain AppKit only for the existing file-panel and accessibility-announcement boundaries.
- Use a secondary-action SwiftUI `Button` for Analysis Record and native `popover` presentation anchored to that trigger.
- Use a SwiftUI tab-style selector or an accessibility-equivalent custom selector whose tabs expose selected state and arrow-key navigation.
- Use `ScrollView` for the active record panel; do not create separately scrolling nested cards.
- Use reusable labeled-value, vector, and matrix views fed only by the immutable `AnalysisRecord` snapshot.
- Render technical values with IBM Plex Mono, selectable text, monospaced digits, stable precision, and explicit accessibility labels that include row, column, channel, and unit where relevant.
- Use the existing `SecondaryActionButtonStyle` for Analysis Record and Export JSON. Keep `PrimaryActionButtonStyle` exclusive to Open Image in the empty state and Export Result in a loaded workspace.
- Use native `NSSavePanel` for the JSON destination and `NSAccessibility.post` for success and failure announcements.
- Use the existing current-result predicate for the Analysis Record trigger, record popover, image export, and JSON export. Do not duplicate currency state in the view.
- Introduce no third-party UI or motion dependency.

## Design Tokens Applied

- `inkStrong` `#142A36`: titles, primary labels, icons, selected tabs, and mathematical values.
- `ink` `#304854`: body copy, section headings, and unselected high-value controls.
- `inkMuted` `#667B84`: explanations, units, metadata, and secondary labels.
- `navy` `#193A4A`: dominant structural tone and popover shadow tint.
- `accent` `#007F92`: active-tab rule, current scientific state, and narrow matrix emphasis only.
- `accentPressed` `#006C7D`: hover and pressed labels for active scientific controls.
- `accentSoft` `#D9F0F3`: light information emphasis and matrix wash.
- `surface` `#F7F9F9`: app and popover footer background.
- `surfaceRaised` `#FFFFFF`: popover, selected segments, and utility controls.
- `surfaceTint` `#EDF3F4`: toolbars, tab strip, formula background, and grouped utility surfaces.
- `canvas` `#DBE3E5`: unchanged image workspace background.
- `divider` `#9FB1B8` and `line` `#C9D4D8`: popover edge and one-point internal structure.
- `success` `#18745F`: current-record state only.
- `warning` `#A35F15`: explanatory caution and recoverable export failure only.
- IBM Plex Sans: 24-point bold record title, 12-point section headings, and 10–12-point body/interface copy.
- IBM Plex Mono: 8–10-point protocol labels, fingerprints, formulas, vectors, matrices, and filenames.
- Spacing scale: 4, 8, 12, 16, 24, and 32 points. Popover outer padding is 18 points; dense labeled rows use 7-point vertical rhythm.
- Radius: 8 points for controls and guidance blocks, 12 points for the popover.
- Depth: one navy-tinted popover shadow; no nested elevation.

## Interaction Notes

- Open the record popover only when the immutable completed record matches the current source and request.
- On open, move focus to the close button or the first logical record control and announce the popover title.
- Left and right arrow keys move among Summary, Matrices, and Applied Transform tabs; tab order continues through selectable values and Export JSON.
- Escape closes the popover and restores focus to Analysis Record.
- Clicking the trigger while open closes the popover and restores focus.
- Switching tabs does not mutate analysis state and never triggers processing.
- Selection and scrolling remain local to the popover; dismissing it restores the unchanged comparison mode, zoom, pan, and region.
- Fingerprints and numerical values support text selection and copying without requiring a separate copy icon on every row.
- Export JSON captures the same current immutable record before opening the save panel. A source or settings change while the panel is open must not cause another record to be substituted.
- If that captured record is no longer current before the write begins, cancel the export with plain guidance instead of writing a mismatched record.
- Disable or close the record surface immediately on image replacement, request change, cancellation, invalid selection, or processing failure.
- VoiceOver matrix values announce row and column labels plus channel names; visual position alone is not the semantic structure.
- Fixed-light control styling remains explicit under both macOS appearance settings.
- The production surface uses real current record values and stable formatting; no example or placeholder values ship.

## Motion Spec

- Record popover open: ease-out, 180 ms, Analysis Record trigger at bottom-right, opacity-only near-instant appearance under Reduce Motion, native SwiftUI popover transition.
- Record popover close: ease-in, 140 ms, Analysis Record trigger at bottom-right, immediate removal under Reduce Motion, native SwiftUI popover transition.
- Tab selection: ease-out, 150 ms, selected tab center, immediate underline/content replacement under Reduce Motion, native SwiftUI animation.
- Tab-panel content change: ease-out, 150 ms, active panel top-leading edge, immediate replacement under Reduce Motion, native SwiftUI opacity transition.
- Record-current state change: ease-out, 150 ms, metadata cluster center, immediate label and availability change under Reduce Motion, native SwiftUI animation.
- Export confirmation: ease-out, 220 ms, bottom-center status origin, immediate appearance and removal under Reduce Motion, native SwiftUI transition.
- Matrix and static numerical content: no entrance, stagger, hover scale, pulse, blur, bounce, or decorative animation.

## Content Notes

Copy stays concise, factual, local, and technically honest. Protocol values, channel names, units, schema identifiers, and exported field labels are not localized; explanatory interface copy may be localized later without changing the JSON contract.

- Use `Analysis Record` for the workspace action and `Analysis record` for the surface title.
- Use `CURRENT · MATCHES DISPLAYED RESULT` only when exact currency checks pass.
- Use `Summary`, `Matrices`, and `Applied transform` as tab labels.
- Describe the surface as `The exact source, settings, and numerical transform behind this result.`
- Keep `This record documents an exploratory enhancement. It does not establish a biological or scientific conclusion.` visible on Summary.
- State `Exported records are deterministic and local.` beside Export JSON.
- Repeat active channel order and units beside every vector and matrix group.
- Use stable scientific values such as `rgb`, `lab`, `covariance`, `correlation`, `wholeImage`, and `selectedRegion` where the UI is showing the export protocol; use established title-case labels in ordinary controls.
- Never describe covariance, correlation, RGB, or Lab as inherently better, more accurate, or more scientific.
- Errors identify the exact problem and recovery action. Prefer `The analysis record could not be saved at that location. Choose another destination; your image and record are unchanged.` over a generic export failure.
