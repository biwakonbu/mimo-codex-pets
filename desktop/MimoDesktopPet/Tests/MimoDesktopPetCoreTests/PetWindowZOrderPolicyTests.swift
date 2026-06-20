import XCTest
@testable import MimoDesktopPetCore

final class PetWindowZOrderPolicyTests: XCTestCase {
    func testCompanionPolicyStaysAboveAppsAcrossSpaces() {
        let policy = PetWindowZOrderPolicy.alwaysOnTopCompanion

        XCTAssertEqual(policy.levelKind, .screenSaver)
        XCTAssertTrue(policy.joinsAllSpaces)
        XCTAssertTrue(policy.joinsFullscreenSpaces)
        XCTAssertTrue(policy.staysOutOfWindowCycle)
        XCTAssertTrue(policy.staysVisibleWhenInactive)
    }
}
