# Design Refinement — Professional App Icon

Status: **APPROVED — 2026-09-14.** The user reviewed the Tailscale preview and responded “Looks great.” Implement this artwork as specified.

## Visual Direction

“Registered color” is an original geometric image-comparison mark. A continuous pale diagonal crosses a navy source field and teal transformed field, separated by a narrow comparison seam. A cool-white macOS tile keeps the silhouette calm and distinct against light and dark surroundings; the tiny lower edge and restrained gradients add depth without gloss or ornamental detail.

The direction extends the established scientific identity. It does not depict a numerical result, promise scientific certainty, or introduce a new brand palette. There is no lettering in the artwork.

## Screens / Views

### Existing system icon surfaces

The repository currently has no custom icon asset. The proposal supplies an identity for Finder, Dock, and app switching; it does not change any application view. Actual installation and OS-surface verification belong to the Engineer after approval.

### Review sheet

`design.html` embeds the SVG master, IBM Plex Sans fonts, and raster proofs without external dependencies. Large light/dark context previews are followed by actual 16, 32, 64, and 128 pixel exports. `icon-presentation.png` supplies an equivalent raster review surface when in-chat browser preview is unavailable. It is a presentation artifact, not a screenshot of a running application.

## Component Usage

The production target remains native SwiftUI/AppKit. This task adds an icon resource, so no controls or third-party component library apply. The static HTML sheet uses semantic headings, sections, figures, image descriptions, and responsive stacking.

## Design Tokens Applied

| Role | Value |
| --- | --- |
| Source image field | `navy` / `#193A4A` |
| Transformed image field | `accent` / `#007F92` to `accentPressed` / `#006C7D` |
| Source diagonal | `accentSoft` / `#D9F0F3` |
| Transformed diagonal | `surfaceRaised` / `#FFFFFF` |
| Comparison seam | `surface` / `#F7F9F9` |
| Tile | `surfaceRaised` / `#FFFFFF` to `surfaceTint` / `#EDF3F4` |
| Tile lower edge | `navy` at 10% opacity |
| Review typography | Bundled IBM Plex Sans, regular and semibold |

Teal identifies the transformed half of the icon; the interface rule limiting teal to the primary action continues unchanged in the app. Display, body, and label roles on the review sheet have explicit weight, line-height, and tracking. This is an artwork-specific application of existing tokens, not a design-system deviation.

## Precise Geometry

Coordinates use the editable SVG's 1024 × 1024 viewBox.

- Tile: `(64,64)`, size `896 × 896`, radius `200`; transparent outside. Lower edge is the same geometry shifted down 8 units, navy at 10% opacity. The top rim is inset 4 units, 8-unit white stroke at 80% opacity.
- Image field: `(224,248)`, size `576 × 528`, radius `80`. The field is vertically centered at 512 and horizontally at 512, with generous tile padding.
- Navy covers the left 288 units; teal covers the right 288 units.
- Shared diagonal polygon: `(224,656) → (800,328) → (800,480) → (224,808)`, clipped to the image field. The source half is pale teal; the transformed half is white. Its uninterrupted slope is the visual link between both views.
- Seam: vertical line at `x=512`, from `248` to `776`, width `24`, clipped to the field.
- No outer opaque canvas, tiny dots, text, photographic detail, or directional badge. The artwork is original and has no external image licensing dependencies.

## Export Notes

Editable master: `icon-master.svg`. Deterministic review exporter: `render-previews.py`, using installed `rsvg-convert` plus Pillow. Run `python3 pipeline/professional-app-icon/render-previews.py` from the repository root; it regenerates all review PNGs and the self-contained HTML from `design-template.html` and the master. Bundled font paths resolve relative to the repository.

Current PNG exports: 16, 32, 64, 128, 256, 512, and 1024 square pixels, all RGBA. The 16 px preview retains the diagonal and split color silhouette; the seam is naturally antialiased below one pixel. No separate small-size artwork is necessary for this first review. A later optical variant should only be introduced if actual Finder/Dock inspection shows a need, and must preserve the same silhouette.

After design approval, the Engineer can reuse exports for the standard macOS icon slots: 16 pt at 1×/2×; 32 pt at 1×/2×; 128 pt at 1×/2×; 256 pt at 1×/2×; 512 pt at 1×/2×. Copying resources and regenerating/building the Xcode project are deliberately pending review.

## Interaction Notes

Static asset. No hover behavior, focus state, menu, loading state, or error state is introduced. Review sizes are actual CSS pixels and use PNG exports to reveal raster behavior.

## Motion Spec

N/A — static macOS application icon and static review sheet. No motion, entrance animation, timing, transform origin, or reduced-motion alternative is required.

## Content Notes

“Registered color” is a review concept title only. The application remains named KLT Image. The proposed icon contains no words or scientific-certainty claims.

## QA and Review Status

- Visually inspected `icon-presentation.png`: light and dark context separation, restrained tile edge, central geometry, diagonal continuity, and 16/32/64/128 px legibility checked.
- `weft-design-lint check pipeline/professional-app-icon/design.html`: clean, 0 findings.
- Self-audit: distinctive existing IBM Plex type; three purposeful typographic roles; tinted neutrals; restrained navy/teal hierarchy; subtle tile/background depth; focused paired-context composition; realistic content; no default component treatment. Motion, popover origins, and dynamic-state checks are N/A for a static asset. Accent is semantically applied to the transformed image field, since this is artwork without a primary action.
- In-chat browser unavailable after the orchestrator's capability troubleshooting; no external browser or workaround was used. The rendered PNG proves artwork appearance, while HTML has deterministic lint verification but has not been browser-rendered.
- User approved the design through the Tailscale preview on 2026-09-14. macOS system-surface verification remains an implementation check.
