# Bug Brief — Comparison Slider Drag
## What is broken
In Slider view, dragging the vertical reveal handle also changes the shared image pan, so both registered images move under the divider.
`ComparisonCanvas` installs `panGesture` with `simultaneousGesture` over the full canvas; the handle’s high-priority drag never marks that pan as suppressed.
The same pointer sequence therefore updates both `comparisonReveal` and `pan`, making the reveal control unreliable.
## Steps to reproduce
1. Open an image, wait for its processed result, and choose **Slider** in the image-view picker.
2. Press the teal reveal handle and drag it horizontally several points.
3. Observe that the image content translates with the drag instead of remaining fixed while only the original/processed boundary moves.
## Expected behavior
Dragging the reveal handle updates `comparisonReveal` continuously and clamps it to 0–1 without changing `pan`.
Dragging elsewhere on the canvas must continue to pan both registered images together.
## Blast radius
The defect is confined to pointer dragging the reveal handle in Slider mode; both original and processed layers move because they share `model.pan`.
Keyboard arrows/Home/End and accessibility adjustments call `setFraction` directly and do not enter the canvas pan gesture.
Current UI coverage verifies only that the Slider option exists, not handle dragging or pan isolation.
## What done looks like
A handle drag scrubs smoothly from edge to edge while the image registration and existing pan value remain unchanged.
A background drag still pans, and selected-region draw/move/resize interactions retain their existing pan suppression.
An interaction regression test proves handle drag changes reveal without changing pan and background drag still changes pan.
