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

    func testDebugMenuIsHiddenInProductionByDefault() {
        XCTAssertFalse(PetDebugOverlayPolicy.isMenuVisible(environment: [:]))
        XCTAssertFalse(PetDebugOverlayPolicy.isMenuVisible(environment: ["MIMO_DEBUG_MENU": "true"]))
    }

    func testDebugMenuIsVisibleWhenExplicitlyEnabledOrOverlayStartsEnabled() {
        XCTAssertTrue(PetDebugOverlayPolicy.isMenuVisible(environment: ["MIMO_DEBUG_MENU": "1"]))
        XCTAssertTrue(PetDebugOverlayPolicy.isMenuVisible(environment: ["MIMO_DEBUG_OVERLAY": "1"]))
    }
}
