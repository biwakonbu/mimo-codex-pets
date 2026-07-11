import XCTest
@testable import MimoDesktopPetCore

final class PetKataribeNarrationPolicyTests: XCTestCase {
    func testWalkingKeepsCurrentNarrationStableAfterItsTimeout() {
        XCTAssertFalse(PetKataribeNarrationPolicy.shouldAdvanceAfterTimeout(isPetMoving: true))
    }

    func testRestingAllowsTheNextChatNarration() {
        XCTAssertTrue(PetKataribeNarrationPolicy.shouldAdvanceAfterTimeout(isPetMoving: false))
        XCTAssertGreaterThanOrEqual(PetKataribeNarrationPolicy.restSettleDelay, 0.6)
    }
}
