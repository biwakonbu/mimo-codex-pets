import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleLayoutTests: XCTestCase {
    func testProductionLayoutFitsWindowWithSprite() {
        XCTAssertEqual(PetSpeechBubbleLayout.productionWindowWidth, 392)
        XCTAssertEqual(PetSpeechBubbleLayout.productionWindowHeight, 408)

        let verticalContent =
            4.0 +
            PetSpeechBubbleLayout.productionStackHeight +
            PetSpeechBubbleLayout.productionSpriteHeight
        XCTAssertLessThanOrEqual(verticalContent, PetSpeechBubbleLayout.productionWindowHeight)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.productionStackWidth, PetSpeechBubbleLayout.productionWindowWidth)
    }

    func testSingleBubbleStaysAnchoredAboveMimo() {
        let placement = PetSpeechBubbleLayout.placement(
            for: 0,
            role: .status,
            visibleCount: 1
        )

        XCTAssertEqual(placement.index, 0)
        XCTAssertEqual(placement.horizontalOffset, 0)
        XCTAssertEqual(placement.verticalOffset, 0)
        XCTAssertEqual(placement.maxTextWidth, 308)
        XCTAssertEqual(placement.zIndex, 4)
    }

    func testThreeBubbleStackFansThreadSummaries() {
        let status = PetSpeechBubbleLayout.placement(
            for: 0,
            role: .status,
            visibleCount: 3
        )
        let firstThread = PetSpeechBubbleLayout.placement(
            for: 1,
            role: .conversation,
            visibleCount: 3
        )
        let secondThread = PetSpeechBubbleLayout.placement(
            for: 2,
            role: .conversation,
            visibleCount: 3
        )

        XCTAssertEqual(status.verticalOffset, -100)
        XCTAssertEqual(firstThread.verticalOffset, -50)
        XCTAssertEqual(secondThread.verticalOffset, 0)
        XCTAssertLessThan(firstThread.horizontalOffset, 0)
        XCTAssertGreaterThan(secondThread.horizontalOffset, 0)
        XCTAssertEqual(firstThread.maxTextWidth, 246)
        XCTAssertEqual(secondThread.maxTextWidth, 246)
        XCTAssertGreaterThan(status.zIndex, firstThread.zIndex)
        XCTAssertGreaterThan(firstThread.zIndex, secondThread.zIndex)
    }

    func testFourBubbleStackShowsThreeThreadSummaries() {
        let status = PetSpeechBubbleLayout.placement(
            for: 0,
            role: .status,
            visibleCount: 4
        )
        let firstThread = PetSpeechBubbleLayout.placement(
            for: 1,
            role: .conversation,
            visibleCount: 4
        )
        let secondThread = PetSpeechBubbleLayout.placement(
            for: 2,
            role: .conversation,
            visibleCount: 4
        )
        let thirdThread = PetSpeechBubbleLayout.placement(
            for: 3,
            role: .conversation,
            visibleCount: 4
        )

        XCTAssertEqual(status.verticalOffset, -136)
        XCTAssertEqual(firstThread.verticalOffset, -92)
        XCTAssertEqual(secondThread.verticalOffset, -46)
        XCTAssertEqual(thirdThread.verticalOffset, 0)
        XCTAssertLessThan(firstThread.horizontalOffset, 0)
        XCTAssertGreaterThan(secondThread.horizontalOffset, 0)
        XCTAssertLessThan(thirdThread.horizontalOffset, secondThread.horizontalOffset)
        XCTAssertEqual(firstThread.maxTextWidth, 246)
        XCTAssertEqual(secondThread.maxTextWidth, 246)
        XCTAssertEqual(thirdThread.maxTextWidth, 246)
    }

    func testPlacementClampsToVisibleLimit() {
        let placement = PetSpeechBubbleLayout.placement(
            for: 9,
            role: .conversation,
            visibleCount: 9
        )

        XCTAssertEqual(placement.index, PetSpeechBubbleLayout.productionVisibleLimit - 1)
        XCTAssertEqual(placement.verticalOffset, 0)
        XCTAssertEqual(placement.horizontalOffset, -18)
    }
}
