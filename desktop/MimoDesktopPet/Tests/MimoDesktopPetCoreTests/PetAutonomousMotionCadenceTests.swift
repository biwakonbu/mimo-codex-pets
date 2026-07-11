import XCTest
@testable import MimoDesktopPetCore

final class PetAutonomousMotionCadenceTests: XCTestCase {
    func testMovementUsesDisplayCadenceAndRestUsesLowPowerCadence() {
        XCTAssertEqual(
            PetAutonomousMotionCadence.interval(isActivelyMoving: true),
            1.0 / 60.0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            PetAutonomousMotionCadence.interval(isActivelyMoving: false),
            0.25,
            accuracy: 0.000_001
        )
    }
}
