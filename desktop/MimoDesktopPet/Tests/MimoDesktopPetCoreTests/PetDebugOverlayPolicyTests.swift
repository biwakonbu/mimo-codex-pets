import XCTest
@testable import MimoDesktopPetCore

final class PetDebugOverlayPolicyTests: XCTestCase {
    func testProductionDefaultDisablesDebugOverlay() {
        XCTAssertFalse(PetDebugOverlayPolicy.isEnabled(environment: [:]))
        XCTAssertFalse(PetDebugOverlayPolicy.isEnabled(environment: ["MIMO_DEBUG_OVERLAY": ""]))
        XCTAssertFalse(PetDebugOverlayPolicy.isEnabled(environment: ["MIMO_DEBUG_OVERLAY": "true"]))
        XCTAssertFalse(PetDebugOverlayPolicy.isEnabled(environment: ["MIMO_DEBUG_OVERLAY": "YES"]))
    }

    func testDebugOverlayRequiresExplicitOne() {
        XCTAssertTrue(PetDebugOverlayPolicy.isEnabled(environment: ["MIMO_DEBUG_OVERLAY": "1"]))
    }
}
