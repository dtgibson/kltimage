import CoreGraphics
import XCTest
@testable import KLTImage

final class ComparisonCanvasInteractionTests: XCTestCase {
    func testRevealHandleDragChangesRevealWithoutPanningAndBackgroundDragStillPans() {
        var gestureState = ComparisonCanvasGestureState()
        let initialPan = CGSize(width: 11, height: -7)

        // A simultaneous parent update may arrive before the handle claims the drag.
        var pan = gestureState.updatedPan(
            translation: CGSize(width: 4, height: 1),
            currentPan: initialPan
        )!
        XCTAssertNotEqual(pan, initialPan)

        let revealUpdate = gestureState.updateRevealDrag(
            proposedFraction: 0.8
        )
        pan = revealUpdate.restoredPan ?? pan

        XCTAssertEqual(revealUpdate.fraction, 0.8, accuracy: 0.000_001)
        XCTAssertEqual(pan, initialPan)
        XCTAssertNil(
            gestureState.updatedPan(
                translation: CGSize(width: 80, height: 20),
                currentPan: pan
            )
        )

        XCTAssertEqual(
            gestureState.updateRevealDrag(proposedFraction: 1.4).fraction,
            1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            gestureState.updateRevealDrag(proposedFraction: -0.3).fraction,
            0,
            accuracy: 0.000_001
        )

        gestureState.endRevealDrag()
        gestureState.endPan()
        pan = gestureState.updatedPan(
            translation: CGSize(width: 30, height: -12),
            currentPan: pan
        )!

        XCTAssertEqual(pan, CGSize(width: 41, height: -19))
    }

    func testRegionEditingRetainsPanSuppression() {
        var gestureState = ComparisonCanvasGestureState()
        let initialPan = CGSize(width: -5, height: 9)
        let movedPan = gestureState.updatedPan(
            translation: CGSize(width: 6, height: 3),
            currentPan: initialPan
        )!
        XCTAssertNotEqual(movedPan, initialPan)

        let restoredPan = gestureState.setPanSuppression(
            .regionEdit,
            isActive: true
        )

        XCTAssertEqual(restoredPan, initialPan)
        XCTAssertNil(
            gestureState.updatedPan(
                translation: CGSize(width: 20, height: 20),
                currentPan: restoredPan!
            )
        )
    }
}
