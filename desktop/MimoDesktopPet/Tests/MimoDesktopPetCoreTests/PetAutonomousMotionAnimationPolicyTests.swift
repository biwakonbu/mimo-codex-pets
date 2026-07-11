import XCTest
@testable import MimoDesktopPetCore

final class PetAutonomousMotionAnimationPolicyTests: XCTestCase {
    func testAnimationWaitsUntilWindowHasMovedAwayFromSegmentOrigin() {
        let motion = tween(startX: 100, targetX: 180)

        XCTAssertNil(PetAutonomousMotionAnimationPolicy.animation(
            for: motion,
            currentOrigin: PetWanderPoint(x: 107.9, y: 200),
            isAlreadyAnimating: false
        ))
        XCTAssertEqual(PetAutonomousMotionAnimationPolicy.animation(
            for: motion,
            currentOrigin: PetWanderPoint(x: 108, y: 200),
            isAlreadyAnimating: false
        ), .runningRight)
    }

    func testActivatedAnimationFacesActualTargetDirection() {
        let motion = tween(startX: 100, targetX: 40)

        XCTAssertEqual(PetAutonomousMotionAnimationPolicy.animation(
            for: motion,
            currentOrigin: PetWanderPoint(x: 91, y: 202),
            isAlreadyAnimating: false
        ), .runningLeft)
    }

    func testActiveMovementCanChangeDirectionWithoutDroppingToIdle() {
        let retargetedMotion = tween(startX: 100, targetX: 40)

        XCTAssertEqual(PetAutonomousMotionAnimationPolicy.animation(
            for: retargetedMotion,
            currentOrigin: PetWanderPoint(x: 99.8, y: 200),
            isAlreadyAnimating: true
        ), .runningLeft)
    }

    private func tween(startX: Double, targetX: Double) -> PetAutonomousMotionTween {
        PetAutonomousMotionTween(
            start: PetWanderPoint(x: startX, y: 200),
            target: PetWanderPoint(x: targetX, y: 200),
            startTime: 0,
            duration: 4
        )
    }
}
