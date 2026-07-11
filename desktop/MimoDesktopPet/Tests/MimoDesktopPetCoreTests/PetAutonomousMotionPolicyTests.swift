import XCTest
@testable import MimoDesktopPetCore

final class PetAutonomousMotionPolicyTests: XCTestCase {
    func testProductionMovesByDefaultUnlessExplicitlyDisabled() {
        XCTAssertTrue(PetAutonomousMotionPolicy.shouldAllowWindowMovement(
            explicitWindowMovementEnabled: nil,
            autonomousTestMode: false,
            autonomousEnergyTestMode: false,
            autonomousForceBegin: false
        ))
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
            explicitWindowMovementEnabled: nil,
            autonomousTestMode: true,
            autonomousEnergyTestMode: false,
            autonomousForceBegin: false
        ))
        XCTAssertTrue(PetAutonomousMotionPolicy.shouldAllowWindowMovement(
            explicitWindowMovementEnabled: nil,
            autonomousTestMode: false,
            autonomousEnergyTestMode: true,
            autonomousForceBegin: false
        ))
        XCTAssertTrue(PetAutonomousMotionPolicy.shouldAllowWindowMovement(
            explicitWindowMovementEnabled: nil,
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

}
