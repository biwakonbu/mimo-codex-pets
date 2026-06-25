import XCTest
@testable import MimoDesktopPetCore

final class PetAutonomousEnergyControllerTests: XCTestCase {
    func testHighStaminaMovesBrisklyWithoutPeggingMaximumSpeed() {
        let controller = PetAutonomousEnergyController(stamina: 1)

        XCTAssertGreaterThan(
            controller.speed(maximumSpeed: 52, moodUnit: 0.5),
            42
        )
        XCTAssertLessThan(
            controller.speed(maximumSpeed: 52, moodUnit: 0.5),
            46
        )
        XCTAssertGreaterThan(
            controller.speed(maximumSpeed: 52, moodUnit: 0),
            40
        )
        XCTAssertLessThanOrEqual(
            controller.speed(maximumSpeed: 52, moodUnit: 1),
            52 * 0.88
        )
    }

    func testSpeedFallsAsStaminaDrops() {
        let energetic = PetAutonomousEnergyController(stamina: 1)
        let tired = PetAutonomousEnergyController(stamina: 0.35)

        XCTAssertLessThan(
            tired.speed(maximumSpeed: 52, moodUnit: 0.5),
            energetic.speed(maximumSpeed: 52, moodUnit: 0.5)
        )
        XCTAssertLessThan(
            tired.speed(maximumSpeed: 52, moodUnit: 0.5),
            28
        )
    }

    func testMovingDrainsAndRestingRecoversStamina() {
        var controller = PetAutonomousEnergyController(
            stamina: 1,
            drainPerSecond: 0.2,
            recoveryPerSecond: 0.5
        )

        controller.update(now: 0, isMoving: true, isResting: false)
        controller.update(now: 2, isMoving: true, isResting: false)
        XCTAssertEqual(controller.stamina, 0.6, accuracy: 0.0001)

        controller.update(now: 3, isMoving: false, isResting: true)
        XCTAssertEqual(controller.stamina, 1, accuracy: 0.0001)
    }

    func testStaminaBelowHalfCanTriggerMoodRest() {
        let justTired = PetAutonomousEnergyController(stamina: 0.49)
        let energetic = PetAutonomousEnergyController(stamina: 0.72)

        XCTAssertTrue(justTired.shouldPauseForRest(moodUnit: 0))
        XCTAssertFalse(justTired.shouldPauseForRest(moodUnit: 1))
        XCTAssertFalse(energetic.shouldPauseForRest(moodUnit: 0))
    }

    func testExhaustedStaminaAlwaysPausesForRest() {
        let exhausted = PetAutonomousEnergyController(stamina: 0.1)

        XCTAssertTrue(exhausted.shouldPauseForRest(moodUnit: 1))
    }

    func testRestDurationAllowsRecoveryToFull() {
        let controller = PetAutonomousEnergyController(
            stamina: 0.25,
            recoveryPerSecond: 0.5
        )

        XCTAssertGreaterThanOrEqual(
            controller.restDuration(moodUnit: 0) * 0.5,
            1 - controller.stamina
        )
        XCTAssertGreaterThanOrEqual(controller.restDuration(moodUnit: 0), 3)
        XCTAssertLessThanOrEqual(controller.restDuration(moodUnit: 1), 12)
    }
}
