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

    func testThreeBubbleStackKeepsPrimaryBubbleAttachedToMimoWithCompactThreadChips() {
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
        XCTAssertEqual(firstThread.verticalOffset, -74)
        XCTAssertEqual(secondThread.verticalOffset, -126)
        XCTAssertLessThan(firstThread.horizontalOffset, 0)
        XCTAssertGreaterThan(secondThread.horizontalOffset, 0)
        XCTAssertEqual(firstThread.maxTextWidth, 190)
        XCTAssertEqual(secondThread.maxTextWidth, 190)
        XCTAssertEqual(firstThread.minTextWidth, 184)
        XCTAssertEqual(secondThread.minTextWidth, 184)
        XCTAssertEqual(firstThread.scale, 0.9)
        XCTAssertEqual(secondThread.scale, 0.9)
        XCTAssertGreaterThan(status.zIndex, firstThread.zIndex)
        XCTAssertGreaterThan(firstThread.zIndex, secondThread.zIndex)
    }

    func testFourBubbleStackFansOutCompactThreadChipsAroundPrimaryBubble() {
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
        XCTAssertEqual(firstThread.verticalOffset, -64)
        XCTAssertEqual(secondThread.verticalOffset, -108)
        XCTAssertEqual(thirdThread.verticalOffset, -158)
        XCTAssertLessThan(firstThread.horizontalOffset, 0)
        XCTAssertGreaterThan(secondThread.horizontalOffset, 0)
        XCTAssertLessThan(thirdThread.horizontalOffset, secondThread.horizontalOffset)
        XCTAssertEqual(firstThread.maxTextWidth, 190)
        XCTAssertEqual(secondThread.maxTextWidth, 190)
        XCTAssertEqual(thirdThread.maxTextWidth, 190)
        XCTAssertTrue([firstThread, secondThread, thirdThread].allSatisfy { $0.minTextWidth == 184 })
        XCTAssertEqual(status.scale, 1)
        XCTAssertEqual(firstThread.scale, 0.9)
        XCTAssertEqual(secondThread.scale, 0.9)
        XCTAssertEqual(thirdThread.scale, 0.9)
        XCTAssertLessThan(firstThread.maxTextWidth, status.maxTextWidth - 100)
    }

    func testFiveBubbleStackKeepsPrimaryReadableAndFansOutThreadChips() {
        let placements = (0..<PetSpeechBubbleLayout.productionVisibleLimit).map { index in
            PetSpeechBubbleLayout.placement(
                for: index,
                role: index == PetSpeechBubbleLayout.productionVisibleLimit - 1 ? .overflow : (index == 0 ? .focus : .conversation),
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
            )
        }

        XCTAssertEqual(placements.map(\.verticalOffset), [0, -58, -98, -140, -184])
        XCTAssertEqual(placements.map(\.horizontalOffset), [0, -110, 110, -110, 110])
        XCTAssertEqual(placements[0].maxTextWidth, 318)
        XCTAssertEqual(placements[1].maxTextWidth, 190)
        XCTAssertEqual(placements[4].maxTextWidth, 168)
        XCTAssertEqual(placements[1].minTextWidth, 184)
        XCTAssertEqual(placements[4].minTextWidth, 158)
        XCTAssertEqual(placements[0].scale, 1)
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.scale <= 0.9 })
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.zIndex < placements[0].zIndex })
    }

    func testOverflowBubbleUsesCounterTreatmentInLastContextSlot() {
        let overflow = PetSpeechBubbleLayout.placement(
            for: PetSpeechBubbleLayout.productionVisibleLimit - 1,
            role: .overflow,
            visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
        )

        XCTAssertEqual(overflow.verticalOffset, -184)
        XCTAssertEqual(overflow.horizontalOffset, 110)
        XCTAssertEqual(overflow.maxTextWidth, 168)
        XCTAssertEqual(overflow.minTextWidth, 158)
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
        XCTAssertEqual(placement.verticalOffset, -184)
        XCTAssertEqual(placement.horizontalOffset, 110)
    }

    func testFourBubbleFanFitsInsideProductionStackWidth() {
        for index in 0..<PetSpeechBubbleLayout.productionVisibleLimit {
            let role: PetSpeechBubbleRole = index == 0 ? .status : (
                index == PetSpeechBubbleLayout.productionVisibleLimit - 1 ? .overflow : .conversation
            )
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

    func testSecondaryThreadChipsStayVisuallySubordinateToFocusedPrimaryBubble() {
        let primary = PetSpeechBubbleLayout.placement(
            for: 0,
            role: .focus,
            visibleCount: 4
        )
        let secondary = (1..<PetSpeechBubbleLayout.productionVisibleLimit).map { index in
            PetSpeechBubbleLayout.placement(
                for: index,
                role: index == PetSpeechBubbleLayout.productionVisibleLimit - 1 ? .overflow : .conversation,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
            )
        }

        XCTAssertEqual(primary.scale, 1)
        XCTAssertEqual(primary.fillOpacity, 0.96)
        XCTAssertEqual(primary.maxTextWidth, 318)
        XCTAssertTrue(secondary.allSatisfy { $0.scale <= 0.9 })
        XCTAssertTrue(secondary.allSatisfy { $0.fillOpacity < primary.fillOpacity })
        XCTAssertTrue(secondary.allSatisfy { $0.maxTextWidth <= 190 || $0.role == .overflow })
        XCTAssertTrue(secondary.allSatisfy { $0.minTextWidth != nil })
    }

    func testClusterGuideStaysSubtleBehindMultipleThreadBubbles() {
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.clusterGuideOpacity, 0.06)
        XCTAssertGreaterThan(PetSpeechBubbleLayout.clusterGuideOpacity, 0)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.clusterGuideLineWidth, 1.25)
        XCTAssertGreaterThan(PetSpeechBubbleLayout.clusterGuideLineWidth, 0)
    }
}
