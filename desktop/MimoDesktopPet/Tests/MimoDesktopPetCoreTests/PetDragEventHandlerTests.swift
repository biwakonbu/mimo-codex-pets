import XCTest
@testable import MimoDesktopPetCore

final class PetDragEventHandlerTests: XCTestCase {
    func testUpdatesAreRelativeToInitialFrameNotAccumulatedWindowPosition() {
        var handler = PetDragEventHandler()
        handler.begin(frame: PetDragFrame(x: 100, y: 200, width: 250, height: 300))

        let first = handler.update(
            screenDeltaX: 10,
            screenDeltaY: 5,
            fallbackFrame: PetDragFrame(x: 999, y: 999, width: 250, height: 300)
        )
        let second = handler.update(
            screenDeltaX: 12,
            screenDeltaY: 8,
            fallbackFrame: first.frame
        )

        XCTAssertEqual(first.frame, PetDragFrame(x: 110, y: 205, width: 250, height: 300))
        XCTAssertEqual(second.frame, PetDragFrame(x: 112, y: 208, width: 250, height: 300))
        XCTAssertTrue(handler.isDragging)
    }

    func testHorizontalDirectionMapsToDragAnimationWithoutEndingSession() {
        var handler = PetDragEventHandler()
        handler.begin(frame: PetDragFrame(x: 100, y: 200, width: 250, height: 300))

        let right = handler.update(
            screenDeltaX: 24,
            screenDeltaY: 0,
            fallbackFrame: PetDragFrame(x: 100, y: 200, width: 250, height: 300)
        )
        let left = handler.update(
            screenDeltaX: -16,
            screenDeltaY: 0,
            fallbackFrame: PetDragFrame(x: 124, y: 200, width: 250, height: 300)
        )

        XCTAssertEqual(right.animation, .runningRight)
        XCTAssertEqual(left.animation, .runningLeft)
        XCTAssertTrue(handler.isDragging)
    }

    func testVerticalMovementKeepsLastHorizontalAnimation() {
        var handler = PetDragEventHandler()
        handler.begin(frame: PetDragFrame(x: 100, y: 200, width: 250, height: 300))

        _ = handler.update(
            screenDeltaX: -12,
            screenDeltaY: 0,
            fallbackFrame: PetDragFrame(x: 100, y: 200, width: 250, height: 300)
        )
        let vertical = handler.update(
            screenDeltaX: 0,
            screenDeltaY: 18,
            fallbackFrame: PetDragFrame(x: 88, y: 200, width: 250, height: 300)
        )

        XCTAssertEqual(vertical.animation, .runningLeft)
        XCTAssertEqual(vertical.frame, PetDragFrame(x: 100, y: 218, width: 250, height: 300))
    }

    func testEndClearsSessionAndNextUpdateUsesNewFallbackFrame() {
        var handler = PetDragEventHandler()
        handler.begin(frame: PetDragFrame(x: 100, y: 200, width: 250, height: 300))
        handler.end()

        let update = handler.update(
            screenDeltaX: 7,
            screenDeltaY: -4,
            fallbackFrame: PetDragFrame(x: 300, y: 400, width: 250, height: 300)
        )

        XCTAssertEqual(update.frame, PetDragFrame(x: 307, y: 396, width: 250, height: 300))
        XCTAssertEqual(update.animation, .runningRight)
        XCTAssertTrue(handler.isDragging)
    }
}
