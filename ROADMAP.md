# Roadmap

This is a living document. It reflects the current best thinking on what to build next — not a contract. Things change as you learn more about your users and your product. Update it freely.

---

## Shipped

- **Count:** 2
- **Last shipped:** Analysis controls — Users can combine RGB or Lab, covariance or correlation, and whole-image or single-rectangle sampling while applying each transform to the full-resolution image.
- **Previously:** Core RGB enhancement workflow — A native Mac app opens common image formats, applies deterministic whole-image RGB covariance decorrelation stretch, compares the result, and exports at full resolution.

---

## Up Next

1. **Reproducible analysis** — Expose transformation data, record settings, and support quantitative comparisons now that the interactive analysis model is established.

---

## On the Horizon

- Custom color spaces.
- Saved and reusable transformation matrices.
- Batch processing.
- Tiled or out-of-core processing for images above 64 megapixels.
- Narrow the tailnet static server's document root from the repository root to published release artifacts only.
