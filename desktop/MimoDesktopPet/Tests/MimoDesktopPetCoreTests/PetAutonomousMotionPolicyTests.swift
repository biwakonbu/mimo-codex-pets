import XCTest
@testable import MimoDesktopPetCore

final class PetAutonomousMotionPolicyTests: XCTestCase {
    func testProductionHoldsPositionWhileConversationBubblesAreActive() {
        XCTAssertTrue(PetAutonomousMotionPolicy.shouldHoldPositionForConversation(
            hasPendingConversationBubbles: true,
            autonomousTestMode: false,
            autonomousEnergyTestMode: false
        ))
    }

    func testConversationHoldDoesNotBlockDeterministicMotionTestModes() {
        XCTAssertFalse(PetAutonomousMotionPolicy.shouldHoldPositionForConversation(
            hasPendingConversationBubbles: true,
            autonomousTestMode: true,
            autonomousEnergyTestMode: false
        ))
        XCTAssertFalse(PetAutonomousMotionPolicy.shouldHoldPositionForConversation(
            hasPendingConversationBubbles: true,
            autonomousTestMode: false,
            autonomousEnergyTestMode: true
        ))
    }

    func testProductionDoesNotMoveWindowUnlessExplicitlyEnabled() {
        XCTAssertFalse(PetAutonomousMotionPolicy.shouldAllowWindowMovement(
            explicitWindowMovementEnabled: false,
            autonomousTestMode: false,
            autonomousEnergyTestMode: false,
            autonomousForceBegin: false
        ))
    }

    func testWindowMovementIsAllowedForExplicitOptInAndDeterministicQA() {
        XCTAssertTrue(PetAutonomousMotionPolicy.shouldAllowWindowMovement(
            explicitWindowMovementEnabled: true,
            autonomousTestMode: false,
            autonomousEnergyTestMode: false,
            autonomousForceBegin: false
        ))
        XCTAssertTrue(PetAutonomousMotionPolicy.shouldAllowWindowMovement(
            explicitWindowMovementEnabled: false,
            autonomousTestMode: true,
            autonomousEnergyTestMode: false,
            autonomousForceBegin: false
        ))
        XCTAssertTrue(PetAutonomousMotionPolicy.shouldAllowWindowMovement(
            explicitWindowMovementEnabled: false,
            autonomousTestMode: false,
            autonomousEnergyTestMode: true,
            autonomousForceBegin: false
        ))
        XCTAssertTrue(PetAutonomousMotionPolicy.shouldAllowWindowMovement(
            explicitWindowMovementEnabled: false,
            autonomousTestMode: false,
            autonomousEnergyTestMode: false,
            autonomousForceBegin: true
        ))
    }

    func testConversationHoldRestUsesProductionDwell() {
        XCTAssertEqual(
            PetAutonomousMotionPolicy.conversationHoldRestUntil(now: 42),
            42 + PetAutonomousMotionTuning.productionConversationHoldSeconds,
            accuracy: 0.0001
        )
    }
}
