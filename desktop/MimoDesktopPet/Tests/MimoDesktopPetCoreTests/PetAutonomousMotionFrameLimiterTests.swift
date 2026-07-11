import XCTest
@testable import MimoDesktopPetCore

final class PetAutonomousMotionFrameLimiterTests: XCTestCase {
    func testLimitsLargeFrameJumpToMaximumSpeed() {
        let origin = PetAutonomousMotionFrameLimiter.limitedOrigin(
            current: PetWanderPoint(x: 0, y: 0),
            desired: PetWanderPoint(x: 300, y: 400),
            maximumSpeed: 120,
            elapsed: 1.0 / 30.0
        )

        XCTAssertEqual(hypot(origin.x, origin.y), 4, accuracy: 0.0001)
    }

    func testReachesDesiredOriginWhenWithinFrameBudget() {
        let origin = PetAutonomousMotionFrameLimiter.limitedOrigin(
            current: PetWanderPoint(x: 10, y: 20),
            desired: PetWanderPoint(x: 12, y: 21),
            maximumSpeed: 120,
            elapsed: 1.0 / 30.0
        )

        XCTAssertEqual(origin, PetWanderPoint(x: 12, y: 21))
    }

    func testClampsLongElapsedSoPausedTweenCannotCatchUpInOneFrame() {
        let origin = PetAutonomousMotionFrameLimiter.limitedOrigin(
            current: PetWanderPoint(x: 0, y: 0),
            desired: PetWanderPoint(x: 300, y: 0),
            maximumSpeed: 90,
            elapsed: 3
        )

        XCTAssertEqual(origin, PetWanderPoint(x: 3, y: 0))
    }

    func testZeroSpeedHoldsCurrentOriginWhenDesiredIsFarAway() {
        let origin = PetAutonomousMotionFrameLimiter.limitedOrigin(
            current: PetWanderPoint(x: 4, y: 8),
            desired: PetWanderPoint(x: 120, y: 80),
            maximumSpeed: 0,
            elapsed: 1.0 / 30.0
        )

        XCTAssertEqual(origin, PetWanderPoint(x: 4, y: 8))
    }
}
