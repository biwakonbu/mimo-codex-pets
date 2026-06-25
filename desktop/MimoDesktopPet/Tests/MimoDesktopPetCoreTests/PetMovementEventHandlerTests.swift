import XCTest
@testable import MimoDesktopPetCore

final class PetMovementEventHandlerTests: XCTestCase {
    func testInitialSampleDoesNotAnimateUntilMovementIsObserved() {
        var handler = PetMovementEventHandler(activationDistance: 8)

        let update = handler.update(
            sample: PetMovementSample(
                frame: PetDragFrame(x: 100, y: 200, width: 250, height: 300),
                timestamp: 0
            )
        )

        XCTAssertFalse(update.isMoving)
        XCTAssertNil(update.animation)
        XCTAssertFalse(handler.isMoving)
    }

    func testCumulativeDisplacementFromOriginActivatesRightAnimation() {
        var handler = PetMovementEventHandler(activationDistance: 10)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))

        let tooClose = handler.update(sample: sample(x: 106, y: 200, t: 0.5))
        let active = handler.update(sample: sample(x: 111, y: 200, t: 1.0))

        XCTAssertFalse(tooClose.isMoving)
        XCTAssertNil(tooClose.animation)
        XCTAssertEqual(tooClose.displacementX, 6)
        XCTAssertTrue(active.isMoving)
        XCTAssertEqual(active.animation, .runningRight)
        XCTAssertEqual(active.displacementX, 11)
    }

    func testLeftDisplacementChoosesLeftAnimation() {
        var handler = PetMovementEventHandler(activationDistance: 8)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))

        let update = handler.update(sample: sample(x: 91, y: 200, t: 0.5))

        XCTAssertTrue(update.isMoving)
        XCTAssertEqual(update.animation, .runningLeft)
        XCTAssertEqual(update.displacementX, -9)
    }

    func testAnimationStaysActiveWhileStillDisplacedEvenWhenCurrentVelocityStops() {
        var handler = PetMovementEventHandler(activationDistance: 8)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))
        _ = handler.update(sample: sample(x: 120, y: 200, t: 1))

        let held = handler.update(sample: sample(x: 120, y: 200, t: 2))

        XCTAssertTrue(held.isMoving)
        XCTAssertEqual(held.animation, .runningRight)
        XCTAssertEqual(held.velocityX, 0, accuracy: 0.0001)
        XCTAssertEqual(held.displacementX, 20)
    }

    func testReturningNearOriginClearsMovementAnimation() {
        var handler = PetMovementEventHandler(activationDistance: 8)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))
        _ = handler.update(sample: sample(x: 112, y: 200, t: 0.5))

        let cleared = handler.update(sample: sample(x: 103, y: 200, t: 1.0))

        XCTAssertFalse(cleared.isMoving)
        XCTAssertNil(cleared.animation)
        XCTAssertFalse(handler.isMoving)
    }

    func testVerticalDisplacementKeepsLastHorizontalAnimation() {
        var handler = PetMovementEventHandler(activationDistance: 8)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))
        _ = handler.update(sample: sample(x: 112, y: 200, t: 0.5))

        let update = handler.update(sample: sample(x: 101, y: 214, t: 1.0))

        XCTAssertTrue(update.isMoving)
        XCTAssertEqual(update.animation, .runningRight)
        XCTAssertEqual(update.displacementY, 14)
    }

    func testNonIncreasingTimestampDoesNotClearActiveMovement() {
        var handler = PetMovementEventHandler(activationDistance: 8)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))
        _ = handler.update(sample: sample(x: 112, y: 200, t: 0.5))

        let update = handler.update(sample: sample(x: 118, y: 200, t: 0.5))

        XCTAssertTrue(update.isMoving)
        XCTAssertEqual(update.animation, .runningRight)
    }

    func testExplicitBeginUsesProvidedOriginForActivationDistance() {
        var handler = PetMovementEventHandler(activationDistance: 8)
        handler.begin(sample: sample(x: 40, y: 50, t: 10))

        let update = handler.update(sample: sample(x: 49, y: 50, t: 10.5))

        XCTAssertTrue(update.isMoving)
        XCTAssertEqual(update.animation, .runningRight)
        XCTAssertEqual(update.displacementX, 9)
    }

    private func sample(x: Double, y: Double, t: TimeInterval) -> PetMovementSample {
        PetMovementSample(
            frame: PetDragFrame(x: x, y: y, width: 250, height: 300),
            timestamp: t
        )
    }
}
