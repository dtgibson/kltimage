# KLT Image Design System

## Feel

KLT Image is precise, confident, quiet, and content-first. It should resemble a well-made scientific instrument rather than a consumer photo filter. The interface never competes with the image or implies more certainty than the method provides.

## Typography

- Display and body: IBM Plex Sans.
- Technical labels, dimensions, and matrix-related values: IBM Plex Mono.
- Display: 18–20 pt, 650–700 weight, tight tracking.
- Body: 12–15 pt, 400–600 weight, approximately 1.5 line height for explanatory copy.
- Label: 10–11 pt, 600 weight, increased tracking; uppercase only for compact status and metadata labels.
- Bundle both font families with the app under their open license. Do not silently fall back to the default system face in shipped surfaces.

## Color Tokens

| Token | Value | Use |
|---|---|---|
| `inkStrong` | `#142A36` | Primary text and icons |
| `ink` | `#304854` | Body text |
| `inkMuted` | `#667B84` | Secondary copy and metadata |
| `navy` | `#193A4A` | Dominant structural color |
| `accent` | `#007F92` | The single primary action and active scientific state |
| `accentPressed` | `#006C7D` | Hover and pressed accent state |
| `accentSoft` | `#D9F0F3` | Information emphasis |
| `surface` | `#F7F9F9` | Window background |
| `surfaceRaised` | `#FFFFFF` | Popovers and raised controls |
| `surfaceTint` | `#EDF3F4` | Toolbars and grouped utility surfaces |
| `canvas` | `#DBE3E5` | Image workspace background |
| `divider` | `#9FB1B8` | Pane division and strong borders |
| `success` | `#18745F` | Completed processing state |
| `warning` | `#A35F15` | Recoverable caution only |

All neutrals are blue-green tinted. Avoid pure black, dead gray, and accent-colored decoration.

## Spacing and Shape

- Spacing scale: 4, 8, 12, 16, 24, 32 points.
- Compact controls: 8-point radius.
- Popovers and utility overlays: 12-point radius.
- Use one-pixel cool-gray dividers instead of excessive card borders.
- Avoid cards inside cards. Prefer a continuous workspace with clear structural regions.

## Depth

- Use a subtle cool atmospheric gradient behind the main window or canvas when appropriate.
- Popovers use a restrained navy-tinted shadow.
- The image canvas may use a faint technical grid at low contrast.
- Keep image panes flat and uninterrupted so the specimen remains the focal point.

## Patterns

### Comparison Workspace

Two synchronized image panes share one canvas. Labels sit directly over each pane, and view mode changes presentation without recalculation. Native controls on the fixed light toolbar explicitly use the matching light appearance, strong ink for unselected labels, and a visible cool-gray boundary so system dark mode cannot erase their resting state.

### Primary Action

Only the most important immediate action receives the filled accent style. In a loaded document this is Export Result; in the empty state it is Open Image.

### Method Disclosure

Show the active method in compact form at all times. Put explanatory and technical details in a trigger-anchored popover rather than a permanent inspector.

### Interpretation Guidance

Keep the exploratory-use limitation visible in the metadata strip. It is calm guidance, not an alarming warning banner.

### Status and Error Placement

Processing and errors appear where the enhanced result belongs. The original image remains available for context.

## Motion

- Use ease-out for entering or changing visible state.
- Keep transitions between 150 and 220 ms.
- Anchor popover motion to its trigger.
- Animate only the region that changed.
- Under Reduce Motion, remove scale and spatial movement and use near-instant opacity changes.
- Avoid bounce, pulse, blur entrances, decorative stagger, and static-content motion on launch.

## References

No external product reference was selected. The direction is anchored to the user's preference for clean, simple scientific tools that emphasize content and build confidence.

## Rationale

Cool tinted neutrals reduce visual contamination around photographs while preserving a deliberate scientific character. Teal provides a clear active-state signal without implying warning or false certainty. IBM Plex gives the app a technical voice while remaining highly readable. A continuous comparison canvas keeps attention on the image evidence rather than the interface.
