import XCTest
@testable import MimoDesktopPetCore

final class PetAutonomousMotionPlannerTests: XCTestCase {
    func testTargetStaysInsideVisibleFrameWithPetSizeAndMargin() {
        let visible = PetDragFrame(x: 100, y: 200, width: 800, height: 600)

        let minimum = PetAutonomousMotionPlanner.target(
            visibleFrame: visible,
            petWidth: 320,
            petHeight: 430,
            randomX: -1,
            randomY: -1
        )
        let maximum = PetAutonomousMotionPlanner.target(
            visibleFrame: visible,
            petWidth: 320,
            petHeight: 430,
            randomX: 2,
            randomY: 2
        )

        XCTAssertEqual(minimum, PetWanderPoint(x: 124, y: 224))
        XCTAssertEqual(maximum, PetWanderPoint(x: 556, y: 346))
    }

    func testStepMovesTowardTargetWithoutOvershooting() {
        let update = PetAutonomousMotionPlanner.step(
            current: PetWanderPoint(x: 0, y: 0),
            target: PetWanderPoint(x: 100, y: 0),
            baseSpeed: 50,
            elapsed: 0.5,
            wave: 1,
            jitter: 1
        )

        XCTAssertFalse(update.reachedTarget)
        XCTAssertEqual(update.origin, PetWanderPoint(x: 10, y: 0))
    }

    func testStepReportsArrivalNearTarget() {
        let update = PetAutonomousMotionPlanner.step(
            current: PetWanderPoint(x: 98, y: 0),
            target: PetWanderPoint(x: 100, y: 0),
            baseSpeed: 50,
            elapsed: 0.1,
            wave: 1,
            jitter: 1
        )

        XCTAssertTrue(update.reachedTarget)
        XCTAssertEqual(update.origin, PetWanderPoint(x: 98, y: 0))
    }

    func testStepUsesWaveAndJitterAsSpeedVariation() {
        let update = PetAutonomousMotionPlanner.step(
            current: PetWanderPoint(x: 0, y: 0),
            target: PetWanderPoint(x: 100, y: 0),
            baseSpeed: 50,
            elapsed: 0.1,
            wave: 0.8,
            jitter: 1.5
        )

        XCTAssertEqual(update.origin.x, 6, accuracy: 0.0001)
        XCTAssertEqual(update.origin.y, 0, accuracy: 0.0001)
    }
}
