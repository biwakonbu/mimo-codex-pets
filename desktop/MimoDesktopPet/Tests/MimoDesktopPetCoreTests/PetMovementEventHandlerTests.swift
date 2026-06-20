import XCTest
@testable import MimoDesktopPetCore

final class PetMovementEventHandlerTests: XCTestCase {
    func testInitialSampleDoesNotAnimateUntilMovementIsObserved() {
        var handler = PetMovementEventHandler()

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

    func testHorizontalVelocityChoosesRightAndLeftAnimation() {
        var handler = PetMovementEventHandler(minimumSpeed: 4, minimumAcceleration: 1_000)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))

        let right = handler.update(sample: sample(x: 112, y: 200, t: 0.5))
        let left = handler.update(sample: sample(x: 96, y: 200, t: 1.0))

        XCTAssertTrue(right.isMoving)
        XCTAssertEqual(right.animation, .runningRight)
        XCTAssertTrue(left.isMoving)
        XCTAssertEqual(left.animation, .runningLeft)
    }

    func testAccelerationCanChooseDirectionBeforeVelocityThreshold() {
        var handler = PetMovementEventHandler(minimumSpeed: 100, minimumAcceleration: 0.5)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))

        let update = handler.update(sample: sample(x: 101, y: 200, t: 1))

        XCTAssertTrue(update.isMoving)
        XCTAssertEqual(update.animation, .runningRight)
        XCTAssertEqual(update.velocityX, 1, accuracy: 0.0001)
        XCTAssertEqual(update.accelerationX, 1, accuracy: 0.0001)
    }

    func testDecelerationDoesNotFlipTheLastHorizontalDirection() {
        var handler = PetMovementEventHandler(minimumSpeed: 10, minimumAcceleration: 5)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))
        _ = handler.update(sample: sample(x: 120, y: 200, t: 1))

        let update = handler.update(sample: sample(x: 125, y: 200, t: 2))

        XCTAssertTrue(update.isMoving)
        XCTAssertLessThan(update.accelerationX, 0)
        XCTAssertEqual(update.animation, .runningRight)
    }

    func testVerticalMovementKeepsLastHorizontalAnimation() {
        var handler = PetMovementEventHandler(minimumSpeed: 4, minimumAcceleration: 1_000)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))
        _ = handler.update(sample: sample(x: 112, y: 200, t: 0.5))

        let update = handler.update(sample: sample(x: 112, y: 218, t: 1.0))

        XCTAssertTrue(update.isMoving)
        XCTAssertEqual(update.animation, .runningRight)
    }

    func testStationarySamplesClearMovementAfterHold() {
        var handler = PetMovementEventHandler(
            minimumSpeed: 4,
            minimumAcceleration: 1_000,
            stationarySampleLimit: 2
        )
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))
        _ = handler.update(sample: sample(x: 112, y: 200, t: 0.5))

        let held = handler.update(sample: sample(x: 112, y: 200, t: 1.0))
        let cleared = handler.update(sample: sample(x: 112, y: 200, t: 1.5))

        XCTAssertTrue(held.isMoving)
        XCTAssertEqual(held.animation, .runningRight)
        XCTAssertFalse(cleared.isMoving)
        XCTAssertNil(cleared.animation)
        XCTAssertFalse(handler.isMoving)
    }

    func testNonIncreasingTimestampDoesNotClearActiveMovement() {
        var handler = PetMovementEventHandler(minimumSpeed: 4, minimumAcceleration: 1_000)
        _ = handler.update(sample: sample(x: 100, y: 200, t: 0))
        _ = handler.update(sample: sample(x: 112, y: 200, t: 0.5))

        let update = handler.update(sample: sample(x: 118, y: 200, t: 0.5))

        XCTAssertTrue(update.isMoving)
        XCTAssertEqual(update.animation, .runningRight)
    }

    private func sample(x: Double, y: Double, t: TimeInterval) -> PetMovementSample {
        PetMovementSample(
            frame: PetDragFrame(x: x, y: y, width: 250, height: 300),
            timestamp: t
        )
    }
}
