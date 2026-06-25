import XCTest
@testable import MimoDesktopPetCore

final class PetManualDragActivationTests: XCTestCase {
    func testSmallPointerMovementDoesNotActivateDrag() {
        var activation = PetManualDragActivation(activationDistance: 4)
        activation.begin(at: PetWanderPoint(x: 10, y: 20))

        let update = activation.update(to: PetWanderPoint(x: 12, y: 22))

        XCTAssertFalse(update.isActive)
        XCTAssertFalse(update.didActivate)
        XCTAssertFalse(activation.isActive)
        XCTAssertEqual(update.screenDeltaX, 2)
        XCTAssertEqual(update.screenDeltaY, 2)
    }

    func testCrossingThresholdActivatesOnceWithTotalDelta() {
        var activation = PetManualDragActivation(activationDistance: 4)
        activation.begin(at: PetWanderPoint(x: 10, y: 20))

        let first = activation.update(to: PetWanderPoint(x: 13, y: 20))
        let second = activation.update(to: PetWanderPoint(x: 15, y: 20))
        let third = activation.update(to: PetWanderPoint(x: 22, y: 18))

        XCTAssertFalse(first.isActive)
        XCTAssertTrue(second.isActive)
        XCTAssertTrue(second.didActivate)
        XCTAssertEqual(second.screenDeltaX, 5)
        XCTAssertEqual(second.screenDeltaY, 0)
        XCTAssertTrue(third.isActive)
        XCTAssertFalse(third.didActivate)
        XCTAssertEqual(third.screenDeltaX, 12)
        XCTAssertEqual(third.screenDeltaY, -2)
    }

    func testEndReturnsWhetherDragWasActiveAndResetsState() {
        var activation = PetManualDragActivation(activationDistance: 4)
        activation.begin(at: PetWanderPoint(x: 0, y: 0))
        _ = activation.update(to: PetWanderPoint(x: 5, y: 0))

        XCTAssertTrue(activation.end())
        XCTAssertFalse(activation.isActive)

        activation.begin(at: PetWanderPoint(x: 0, y: 0))
        _ = activation.update(to: PetWanderPoint(x: 1, y: 1))

        XCTAssertFalse(activation.end())
        XCTAssertFalse(activation.isActive)
    }
}
