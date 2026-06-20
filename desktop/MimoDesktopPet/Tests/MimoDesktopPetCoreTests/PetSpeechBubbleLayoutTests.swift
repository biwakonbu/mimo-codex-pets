import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleLayoutTests: XCTestCase {
    func testProductionLayoutFitsWindowWithSprite() {
        XCTAssertEqual(PetSpeechBubbleLayout.productionWindowWidth, 432)
        XCTAssertEqual(PetSpeechBubbleLayout.productionWindowHeight, 438)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.productionWindowWidth, 440)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.productionWindowHeight, 440)

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
        XCTAssertEqual(placement.maxTextWidth, 318)
        XCTAssertEqual(placement.scale, 1)
        XCTAssertEqual(placement.zIndex, 10)
    }

    func testFocusedThreadBubbleUsesPrimaryGeometryWithLongerTwoLineText() {
        let placement = PetSpeechBubbleLayout.placement(
            for: 0,
            role: .focus,
            visibleCount: 4
        )

        XCTAssertEqual(placement.index, 0)
        XCTAssertEqual(placement.horizontalOffset, 0)
        XCTAssertEqual(placement.verticalOffset, 0)
        XCTAssertEqual(placement.maxTextWidth, 318)
        XCTAssertEqual(placement.scale, 1)
        XCTAssertEqual(PetSpeechBubbleLayout.textLimit(for: .focus), 48)
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .focus), 2)
    }

    func testThreeBubbleStackKeepsPrimaryBubbleAttachedToMimo() {
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

        XCTAssertEqual(status.verticalOffset, 0)
        XCTAssertEqual(firstThread.verticalOffset, -78)
        XCTAssertEqual(secondThread.verticalOffset, -134)
        XCTAssertLessThan(firstThread.horizontalOffset, 0)
        XCTAssertGreaterThan(secondThread.horizontalOffset, 0)
        XCTAssertEqual(firstThread.maxTextWidth, 216)
        XCTAssertEqual(secondThread.maxTextWidth, 216)
        XCTAssertEqual(firstThread.scale, 0.94)
        XCTAssertEqual(secondThread.scale, 0.94)
        XCTAssertGreaterThan(status.zIndex, firstThread.zIndex)
        XCTAssertGreaterThan(firstThread.zIndex, secondThread.zIndex)
    }

    func testFourBubbleStackShowsThreeThreadSummariesAsCompactContext() {
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

        XCTAssertEqual(status.verticalOffset, 0)
        XCTAssertEqual(firstThread.verticalOffset, -72)
        XCTAssertEqual(secondThread.verticalOffset, -124)
        XCTAssertEqual(thirdThread.verticalOffset, -176)
        XCTAssertLessThan(firstThread.horizontalOffset, 0)
        XCTAssertGreaterThan(secondThread.horizontalOffset, 0)
        XCTAssertLessThan(thirdThread.horizontalOffset, secondThread.horizontalOffset)
        XCTAssertEqual(firstThread.maxTextWidth, 216)
        XCTAssertEqual(secondThread.maxTextWidth, 216)
        XCTAssertEqual(thirdThread.maxTextWidth, 216)
        XCTAssertEqual(status.scale, 1)
        XCTAssertEqual(firstThread.scale, 0.94)
        XCTAssertEqual(secondThread.scale, 0.94)
        XCTAssertEqual(thirdThread.scale, 0.94)
    }

    func testOverflowBubbleUsesCounterTreatmentInLastContextSlot() {
        let overflow = PetSpeechBubbleLayout.placement(
            for: 3,
            role: .overflow,
            visibleCount: 4
        )

        XCTAssertEqual(overflow.verticalOffset, -176)
        XCTAssertEqual(overflow.horizontalOffset, -46)
        XCTAssertEqual(overflow.maxTextWidth, 176)
        XCTAssertEqual(overflow.fillOpacity, 0.88)
        XCTAssertEqual(overflow.scale, 0.9)
        XCTAssertEqual(PetSpeechBubbleLayout.textLimit(for: .overflow), 22)
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .overflow), 1)
    }

    func testPlacementClampsToVisibleLimit() {
        let placement = PetSpeechBubbleLayout.placement(
            for: 9,
            role: .conversation,
            visibleCount: 9
        )

        XCTAssertEqual(placement.index, PetSpeechBubbleLayout.productionVisibleLimit - 1)
        XCTAssertEqual(placement.verticalOffset, -176)
        XCTAssertEqual(placement.horizontalOffset, -46)
    }

    func testFourBubbleFanFitsInsideProductionStackWidth() {
        for index in 0..<PetSpeechBubbleLayout.productionVisibleLimit {
            let role: PetSpeechBubbleRole = index == 0 ? .status : (index == 3 ? .overflow : .conversation)
            let placement = PetSpeechBubbleLayout.placement(
                for: index,
                role: role,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
            )
            let centerX = PetSpeechBubbleLayout.productionStackWidth / 2 + placement.horizontalOffset
            let halfWidth = placement.maxTextWidth / 2

            XCTAssertGreaterThanOrEqual(centerX - halfWidth, 0)
            XCTAssertLessThanOrEqual(centerX + halfWidth, PetSpeechBubbleLayout.productionStackWidth)
        }
    }

    func testPrimaryBubbleStaysLowestAndMostProminentInMultiThreadStack() {
        let placements = (0..<PetSpeechBubbleLayout.productionVisibleLimit).map { index in
            PetSpeechBubbleLayout.placement(
                for: index,
                role: index == 0 ? .status : .conversation,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
            )
        }
        let primary = placements[0]

        XCTAssertEqual(primary.verticalOffset, 0)
        XCTAssertEqual(primary.scale, 1)
        XCTAssertEqual(primary.maxTextWidth, 318)
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.verticalOffset < primary.verticalOffset })
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.scale < primary.scale })
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.maxTextWidth < primary.maxTextWidth })
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.zIndex < primary.zIndex })
    }
}
