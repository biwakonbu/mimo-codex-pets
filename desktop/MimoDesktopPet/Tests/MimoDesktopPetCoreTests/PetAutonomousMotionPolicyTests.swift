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

    func testAnchoredProductionUsesEarlierInPlaceMomentsThanWindowMovementMode() {
        XCTAssertEqual(
            PetAutonomousMotionPolicy.initialIdleMomentDelay(windowMovementEnabled: false),
            PetAutonomousMotionTuning.productionAnchoredInitialMomentSeconds
        )
        XCTAssertEqual(
            PetAutonomousMotionPolicy.initialIdleMomentDelay(windowMovementEnabled: true),
            PetAutonomousMotionTuning.productionInitialRestSeconds
        )
        XCTAssertLessThan(
            PetAutonomousMotionPolicy.initialIdleMomentDelay(windowMovementEnabled: false),
            PetAutonomousMotionPolicy.initialIdleMomentDelay(windowMovementEnabled: true)
        )
    }

    func testAnchoredProductionUsesGentleInPlaceMomentCadence() {
        XCTAssertEqual(
            PetAutonomousMotionPolicy.idleMomentDelayRange(windowMovementEnabled: false),
            PetAutonomousMotionTuning.productionAnchoredIdleMomentDelayRange
        )
        XCTAssertEqual(
            PetAutonomousMotionPolicy.restMomentDelayRange(windowMovementEnabled: false),
            PetAutonomousMotionTuning.productionAnchoredRestMomentDelayRange
        )
        XCTAssertEqual(
            PetAutonomousMotionPolicy.idleMomentDelayRange(windowMovementEnabled: true),
            PetAutonomousMotionTuning.productionIdleMomentDelayRange
        )
        XCTAssertEqual(
            PetAutonomousMotionPolicy.restMomentDelayRange(windowMovementEnabled: true),
            PetAutonomousMotionTuning.productionRestMomentDelayRange
        )
    }

    func testConversationHoldRestUsesProductionDwell() {
        XCTAssertEqual(
            PetAutonomousMotionPolicy.conversationHoldRestUntil(now: 42),
            42 + PetAutonomousMotionTuning.productionConversationHoldSeconds,
            accuracy: 0.0001
        )
    }
}
