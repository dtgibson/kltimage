## RGB fidelity and extended zoom

### What this does
Raises existing Mac, iPhone, and iPad zoom controls and pinch to one shared 1000% fit-relative ceiling. Adds controlled pixel-level fidelity checks for lossless and JPEG sources. The supplied affected JPEG reproduces blockiness in full-resolution RGB PNG exports: source chroma blocks are amplified by the transform, with no missing pixels or pixel-mapping error. No image-processing or interpolation changes were justified.

### How to test
1. Open the generated `source.png` and `source.jpg` fixtures in the native Mac app or local iPhone/iPad Simulator.
2. Repeatedly zoom in with buttons and pinch; confirm 1000%, overshoot clamping, zoom-out and Fit. Check panning, sample geometry and slider drag ownership at maximum zoom.
3. Compare matching regions across Original, Processed, Side-by-Side and Slider, and against exported reference crops; repeat RGB/Lab covariance/correlation.
4. Review the signed Debug, ReleaseTests and simulator run evidence in `implementation-record.md`.

### Notes for reviewer
100% still means Fit; existing platform minimums remain 25% on Mac and 100% on iOS. The controlled JPEG input has materially larger RGB output differences than Lab, even with exact scalar pixel mapping. The affected image now confirms visible compression-block amplification in exported RGB pixels, so this change does not claim to remove that artifact. A focused iPhone native UI test passed buttons/pinch/overshoot/Fit; matched native screen/export checks and other platform gesture checks remain limited; no physical devices or production release channels were used.
