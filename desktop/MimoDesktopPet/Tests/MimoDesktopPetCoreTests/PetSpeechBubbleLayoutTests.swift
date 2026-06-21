import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleLayoutTests: XCTestCase {
    func testProductionLayoutFitsWindowWithSprite() {
        XCTAssertEqual(PetSpeechBubbleLayout.productionWindowWidth, 432)
        XCTAssertEqual(PetSpeechBubbleLayout.productionWindowHeight, 530)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.productionWindowWidth, 440)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.productionWindowHeight, 560)

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
        XCTAssertEqual(placement.maxTextWidth, 416)
        XCTAssertEqual(placement.minTextWidth, 398)
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
        XCTAssertEqual(placement.maxTextWidth, 416)
        XCTAssertEqual(placement.minTextWidth, 398)
        XCTAssertEqual(placement.scale, 1)
        XCTAssertEqual(PetSpeechBubbleLayout.textLimit(for: .focus), 156)
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .focus), 3)
    }

    func testThreeBubbleStackKeepsPrimaryBubbleAttachedToMimoWithStackedThreadRows() {
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
        XCTAssertEqual(status.minTextWidth, 398)
        XCTAssertEqual(firstThread.verticalOffset, -92)
        XCTAssertEqual(secondThread.verticalOffset, -140)
        XCTAssertEqual(firstThread.horizontalOffset, -10)
        XCTAssertEqual(secondThread.horizontalOffset, 12)
        XCTAssertEqual(firstThread.maxTextWidth, 392)
        XCTAssertEqual(secondThread.maxTextWidth, 392)
        XCTAssertEqual(firstThread.minTextWidth, 370)
        XCTAssertEqual(secondThread.minTextWidth, 370)
        XCTAssertEqual(firstThread.scale, 1)
        XCTAssertEqual(secondThread.scale, 1)
        XCTAssertGreaterThan(status.zIndex, firstThread.zIndex)
        XCTAssertGreaterThan(firstThread.zIndex, secondThread.zIndex)
    }

    func testFourBubbleStackAlignsThreadRowsAbovePrimaryBubble() {
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
        XCTAssertEqual(firstThread.verticalOffset, -92)
        XCTAssertEqual(secondThread.verticalOffset, -140)
        XCTAssertEqual(thirdThread.verticalOffset, -188)
        XCTAssertEqual(firstThread.horizontalOffset, -10)
        XCTAssertEqual(secondThread.horizontalOffset, 12)
        XCTAssertEqual(thirdThread.horizontalOffset, -8)
        XCTAssertEqual(firstThread.maxTextWidth, 392)
        XCTAssertEqual(secondThread.maxTextWidth, 392)
        XCTAssertEqual(thirdThread.maxTextWidth, 392)
        XCTAssertTrue([firstThread, secondThread, thirdThread].allSatisfy { $0.minTextWidth == 370 })
        XCTAssertEqual(status.scale, 1)
        XCTAssertEqual(firstThread.scale, 1)
        XCTAssertEqual(secondThread.scale, 1)
        XCTAssertEqual(thirdThread.scale, 1)
        XCTAssertLessThan(firstThread.maxTextWidth, status.maxTextWidth)
    }

    func testFiveBubbleStackKeepsPrimaryReadableAndStacksThreadRows() {
        let placements = (0..<PetSpeechBubbleLayout.productionVisibleLimit).map { index in
            PetSpeechBubbleLayout.placement(
                for: index,
                role: index == PetSpeechBubbleLayout.productionVisibleLimit - 1 ? .overflow : (index == 0 ? .focus : .conversation),
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
            )
        }

        XCTAssertEqual(placements.map(\.verticalOffset), [0, -92, -140, -188, -236])
        XCTAssertEqual(placements.map(\.horizontalOffset), [0, -10, 12, -8, 10])
        XCTAssertEqual(placements[0].maxTextWidth, 416)
        XCTAssertEqual(placements[0].minTextWidth, 398)
        XCTAssertEqual(placements[1].maxTextWidth, 392)
        XCTAssertEqual(placements[4].maxTextWidth, 320)
        XCTAssertEqual(placements[1].minTextWidth, 370)
        XCTAssertEqual(placements[4].minTextWidth, 270)
        XCTAssertEqual(placements[0].scale, 1)
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.scale == 1 })
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.zIndex < placements[0].zIndex })
    }

    func testOverflowBubbleUsesCounterTreatmentInLastContextSlot() {
        let overflow = PetSpeechBubbleLayout.placement(
            for: PetSpeechBubbleLayout.productionVisibleLimit - 1,
            role: .overflow,
            visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
        )

        XCTAssertEqual(overflow.verticalOffset, -236)
        XCTAssertEqual(overflow.horizontalOffset, 10)
        XCTAssertEqual(overflow.maxTextWidth, 320)
        XCTAssertEqual(overflow.minTextWidth, 270)
        XCTAssertEqual(overflow.fillOpacity, 0.88)
        XCTAssertEqual(overflow.scale, 1)
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
        XCTAssertEqual(placement.verticalOffset, -236)
        XCTAssertEqual(placement.horizontalOffset, 10)
    }

    func testStaggeredThreadRowsFitInsideProductionStackWidth() {
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
        XCTAssertEqual(primary.maxTextWidth, 416)
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.verticalOffset < primary.verticalOffset })
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.scale == primary.scale })
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.maxTextWidth < primary.maxTextWidth })
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.zIndex < primary.zIndex })
    }

    func testSecondaryThreadRowsStayVisuallySubordinateToFocusedPrimaryBubble() {
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
        XCTAssertEqual(primary.maxTextWidth, 416)
        XCTAssertTrue(secondary.allSatisfy { $0.scale == 1 })
        XCTAssertTrue(secondary.allSatisfy { $0.fillOpacity < primary.fillOpacity })
        XCTAssertTrue(secondary.allSatisfy { $0.maxTextWidth <= 392 || $0.role == .overflow })
        XCTAssertTrue(secondary.allSatisfy { $0.minTextWidth != nil })
    }

    func testStackedThreadRowsUseCompactSpacing() {
        XCTAssertEqual(PetSpeechBubbleLayout.productionRowSpacing, 5)
        XCTAssertGreaterThan(PetSpeechBubbleLayout.productionRowSpacing, 0)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.productionRowSpacing, 7)
    }

    func testBubbleTransitionMotionUsesShortSubtleTimings() {
        XCTAssertEqual(PetSpeechBubbleLayout.transitionInsertionOffsetY, 18)
        XCTAssertEqual(PetSpeechBubbleLayout.transitionRemovalOffsetY, -14)
        XCTAssertEqual(PetSpeechBubbleLayout.transitionInsertionScale, 0.96)
        XCTAssertEqual(PetSpeechBubbleLayout.transitionRemovalScale, 0.98)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.stackAnimationResponse, 0.4)
        XCTAssertGreaterThanOrEqual(PetSpeechBubbleLayout.stackAnimationDampingFraction, 0.8)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.contentAnimationDuration, 0.2)
    }

    func testSecondaryRowsAreSubtlyStaggeredForMultiThreadReadability() {
        let placements = (0..<PetSpeechBubbleLayout.productionVisibleLimit).map { index in
            PetSpeechBubbleLayout.placement(
                for: index,
                role: index == 0 ? .focus : (
                    index == PetSpeechBubbleLayout.productionVisibleLimit - 1 ? .overflow : .conversation
                ),
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
            )
        }

        XCTAssertEqual(placements[0].horizontalOffset, 0)
        XCTAssertTrue(placements.dropFirst().contains { $0.horizontalOffset < 0 })
        XCTAssertTrue(placements.dropFirst().contains { $0.horizontalOffset > 0 })
        XCTAssertTrue(placements.dropFirst().allSatisfy { abs($0.horizontalOffset) <= 12 })
    }
}
