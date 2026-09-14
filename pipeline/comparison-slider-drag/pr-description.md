# Comparison Slider Drag

## What this does

- Routes reveal-handle drags through the comparison canvas gesture coordinator so they suppress the simultaneous canvas pan.
- Restores the pan value if the canvas receives the first update from the same pointer sequence before the handle claims it.
- Keeps background dragging, reveal clamping, keyboard and accessibility reveal controls, and selected-region pan suppression unchanged.
- Adds focused interaction regression coverage for reveal dragging, background panning, clamping, and selected-region suppression.

## How to test

1. Open an image and wait for the processed result.
2. Select **Slider** in the image-view picker.
3. Drag the teal reveal handle horizontally and confirm only the reveal boundary moves.
4. Drag the canvas away from the handle and confirm both registered image layers pan together.
5. Run the focused test command:

   ```sh
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project KLTImage.xcodeproj -scheme KLTImage -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/kltimage-comparison-slider-derived -only-testing:KLTImageTests/ComparisonCanvasInteractionTests CODE_SIGNING_ALLOWED=NO
   ```

## Notes for reviewer

The fix is at the competing gestures' shared boundary rather than in the workspace model. `ComparisonCanvasGestureState` records active pan suppressions and the pan value at gesture start. A reveal or selected-region interaction cancels and restores any simultaneous pan update, while an ordinary canvas drag continues to use the same start-plus-translation behavior.

