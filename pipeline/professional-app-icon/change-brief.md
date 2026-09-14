# Change Brief — Professional App Icon

## What is changing
Give KLT Image a simple, professional macOS application icon that carries its established quiet scientific identity into Finder, the Dock, and the app switcher. The repository has no custom icon asset; the generated Xcode project already names `AppIcon` but has no matching asset catalog. This is a refinement of the existing app identity and system presentation, with no new behavior, screen, or data model.

## Why now
Saved idea `b3600c2f-95f1-4b72-87a4-6978fd5b4941` requests: “Create a simple and professional icon for the app.” The existing public native app has a defined visual language but lacks a corresponding application icon resource.

## User-facing impact
KLT Image becomes recognizable through a consistent icon on existing macOS application surfaces. Use the established teal `#007F92`, navy `#193A4A`, and cool light neutrals as the starting palette; convey precise image/color analysis with a clear silhouette and restrained detail. The icon must remain legible at small sizes and on light and dark system backgrounds.

## Design pass
Needed — refine the existing Finder, Dock, and app-switcher presentation with an original icon that feels calm, precise, and finished. The Designer will explore and present concrete artwork to the user before implementation, including small-size and macOS-context previews. Extend the existing scientific visual language; do not establish a new brand direction or make scientific-certainty claims.

## Scope
- Design artifacts and editable master under `pipeline/professional-app-icon/`, plus production icon images and asset metadata under `KLTImage/Resources/Assets.xcassets/AppIcon.appiconset/` or an equivalently native macOS icon resource structure selected by the Designer/Engineer.
- Make app-icon selection explicit in `project.yml` as needed and regenerate `KLTImage.xcodeproj`; verify resources compile into the application rather than merely copying source artwork.
- Provide all standard macOS 16, 32, 128, 256, and 512-point slots at 1× and 2×, with an intentional small-size rendition where needed; retain reproducible export instructions or tooling.
- Exclude application flows, SwiftUI screen styling, `KLTCore`, image processing, methods, persistence, entitlements, document-type icons, website branding, and unrelated assets.
- If packaged for release later in this run, use a fresh versioned artifact and the existing signed/notarized verification workflow; do not overwrite the published Build 7 package.

## Decisions touched
- **Keep results exploratory and local — 2026-09-10:** preserve the exploratory scientific positioning; no product network path or data handling changes.
- **Require trusted signing for every downloadable build — 2026-09-12:** icon resource changes must be included before signing; any downloadable candidate still requires full notarization and independent verification.
- **Make GitHub the canonical release channel — 2026-09-14:** any later approved publication follows the existing GitHub release path and retains trusted rollback artifacts.
- No recorded decision is reversed. The visual foundation comes from `pipeline/design-system.md` and `CLAUDE.md`; no existing icon-specific decision is recorded.

## What done looks like
The user accepts the Designer's icon; production assets match that design and remain clear at 16–1024 pixels, with correct transparency, padding, and no clipped edges or accidental halos.
A regenerated build resolves its bundle icon and shows the intended artwork in Finder, the Dock, and the app switcher; Debug and Release verification meet project requirements without behavioral regressions.
The editable master and export method are retained, and any downloadable build passes the existing signed release checks with its icon present in the verified package.
