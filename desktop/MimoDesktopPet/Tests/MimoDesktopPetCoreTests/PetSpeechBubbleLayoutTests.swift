import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleLayoutTests: XCTestCase {
    func testProductionLayoutFitsWindowWithSprite() {
        XCTAssertEqual(PetSpeechBubbleLayout.productionWindowWidth, 520)
        XCTAssertEqual(PetSpeechBubbleLayout.productionWindowHeight, 520)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.productionWindowWidth, 520)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.productionWindowHeight, 520)
        XCTAssertEqual(PetSpeechBubbleLayout.productionStackVisualOffsetY, -20)
        XCTAssertEqual(PetSpeechBubbleLayout.productionSpriteVisualOffsetY, -16)

        let verticalContent =
            PetSpeechBubbleLayout.productionTopPadding +
            PetSpeechBubbleLayout.productionStackHeight +
            PetSpeechBubbleLayout.productionSpriteHeight
        XCTAssertEqual(verticalContent, PetSpeechBubbleLayout.productionWindowHeight)
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
        XCTAssertEqual(placement.maxTextWidth, 404)
        XCTAssertEqual(placement.minTextWidth, 320)
        XCTAssertEqual(placement.scale, 1)
        XCTAssertEqual(placement.fontScale, 1)
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
        XCTAssertEqual(placement.maxTextWidth, 404)
        XCTAssertEqual(placement.minTextWidth, 336)
        XCTAssertEqual(placement.scale, 1)
        XCTAssertEqual(PetSpeechBubbleLayout.textLimit(for: .focus), 156)
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .focus), 4)
        XCTAssertEqual(PetSpeechBubbleLayout.titleLineLimit(for: .focus), 2)
        XCTAssertEqual(PetSpeechBubbleLayout.summaryLineLimit(for: .focus), 2)
    }

    func testThreeBubbleStackPlacesPrimarySpeechClosestToMimo() {
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
        XCTAssertEqual(status.minTextWidth, 320)
        XCTAssertEqual(firstThread.verticalOffset, -112)
        XCTAssertEqual(secondThread.verticalOffset, -118)
        XCTAssertEqual(firstThread.horizontalOffset, -134)
        XCTAssertEqual(secondThread.horizontalOffset, 134)
        XCTAssertEqual(firstThread.maxTextWidth, 218)
        XCTAssertEqual(secondThread.maxTextWidth, 218)
        XCTAssertEqual(firstThread.minTextWidth, 178)
        XCTAssertEqual(secondThread.minTextWidth, 178)
        XCTAssertEqual(firstThread.scale, 0.96)
        XCTAssertEqual(secondThread.scale, 0.96)
        XCTAssertGreaterThan(status.zIndex, firstThread.zIndex)
        XCTAssertGreaterThan(firstThread.zIndex, secondThread.zIndex)
    }

    func testFourBubbleStackKeepsThreadCardsAbovePrimarySpeech() {
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
        XCTAssertEqual(firstThread.verticalOffset, -112)
        XCTAssertEqual(secondThread.verticalOffset, -118)
        XCTAssertEqual(thirdThread.verticalOffset, -172)
        XCTAssertEqual(firstThread.horizontalOffset, -134)
        XCTAssertEqual(secondThread.horizontalOffset, 134)
        XCTAssertEqual(thirdThread.horizontalOffset, 18)
        XCTAssertEqual(firstThread.maxTextWidth, 218)
        XCTAssertEqual(secondThread.maxTextWidth, 218)
        XCTAssertEqual(thirdThread.maxTextWidth, 218)
        XCTAssertTrue([firstThread, secondThread, thirdThread].allSatisfy { $0.minTextWidth == 178 })
        XCTAssertEqual(status.scale, 1)
        XCTAssertEqual(firstThread.scale, 0.96)
        XCTAssertEqual(secondThread.scale, 0.96)
        XCTAssertEqual(thirdThread.scale, 0.92)
        XCTAssertLessThan(firstThread.maxTextWidth, status.maxTextWidth)
    }

    func testFourBubbleStackKeepsPrimaryReadableAndStacksThreadRows() {
        let placements = (0..<PetSpeechBubbleLayout.productionVisibleLimit).map { index in
            PetSpeechBubbleLayout.placement(
                for: index,
                role: index == PetSpeechBubbleLayout.productionVisibleLimit - 1 ? .overflow : (index == 0 ? .focus : .conversation),
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
            )
        }

        XCTAssertEqual(placements.map(\.verticalOffset), [0, -112, -118, -172])
        XCTAssertEqual(placements.map(\.horizontalOffset), [0, -134, 134, 18])
        XCTAssertEqual(placements[0].maxTextWidth, 404)
        XCTAssertEqual(placements[0].minTextWidth, 336)
        XCTAssertEqual(placements[1].maxTextWidth, 218)
        XCTAssertEqual(placements[3].maxTextWidth, 184)
        XCTAssertEqual(placements[1].minTextWidth, 178)
        XCTAssertEqual(placements[3].minTextWidth, 154)
        XCTAssertEqual(placements[0].scale, 1)
        XCTAssertEqual(placements[1].scale, 0.96)
        XCTAssertEqual(placements[2].scale, 0.96)
        XCTAssertEqual(placements[3].scale, 0.92)
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.zIndex < placements[0].zIndex })
    }

    func testOverflowBubbleUsesCounterTreatmentInLastContextSlot() {
        let overflow = PetSpeechBubbleLayout.placement(
            for: PetSpeechBubbleLayout.productionVisibleLimit - 1,
            role: .overflow,
            visibleCount: PetSpeechBubbleLayout.productionVisibleLimit
        )

        XCTAssertEqual(overflow.verticalOffset, -172)
        XCTAssertEqual(overflow.horizontalOffset, 18)
        XCTAssertEqual(overflow.maxTextWidth, 184)
        XCTAssertEqual(overflow.minTextWidth, 154)
        XCTAssertEqual(overflow.fillOpacity, 0.9)
        XCTAssertEqual(overflow.scale, 0.92)
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
        XCTAssertEqual(placement.verticalOffset, -172)
        XCTAssertEqual(placement.horizontalOffset, 18)
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

    func testPrimaryBubbleStaysLargestAndClosestToMimoInMultiThreadStack() {
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
        XCTAssertEqual(primary.maxTextWidth, 404)
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.verticalOffset < primary.verticalOffset })
        XCTAssertTrue(placements.dropFirst().allSatisfy { $0.scale < primary.scale })
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
        XCTAssertEqual(primary.fillOpacity, 0.97)
        XCTAssertEqual(primary.maxTextWidth, 404)
        XCTAssertTrue(secondary.allSatisfy { $0.scale < primary.scale })
        XCTAssertTrue(secondary.allSatisfy { $0.fillOpacity < primary.fillOpacity })
        XCTAssertTrue(secondary.allSatisfy { $0.maxTextWidth <= 218 })
        XCTAssertTrue(secondary.allSatisfy { $0.minTextWidth != nil })
    }

    func testStackedThreadRowsUseCompactSpacing() {
        XCTAssertEqual(PetSpeechBubbleLayout.productionRowSpacing, 8)
        XCTAssertGreaterThan(PetSpeechBubbleLayout.productionRowSpacing, 0)
        XCTAssertLessThanOrEqual(PetSpeechBubbleLayout.productionRowSpacing, 10)
    }

    func testBubbleTransitionMotionUsesReadableExpressiveTimings() {
        XCTAssertEqual(PetSpeechBubbleLayout.transitionInsertionOffsetY, 62)
        XCTAssertEqual(PetSpeechBubbleLayout.transitionRemovalOffsetY, -46)
        XCTAssertEqual(PetSpeechBubbleLayout.transitionInsertionScale, 0.74)
        XCTAssertEqual(PetSpeechBubbleLayout.transitionRemovalScale, 0.9)
        XCTAssertEqual(PetSpeechBubbleLayout.stackAnimationResponse, 0.92)
        XCTAssertEqual(PetSpeechBubbleLayout.stackAnimationDampingFraction, 0.78)
        XCTAssertEqual(PetSpeechBubbleLayout.stackAnimationBlendDuration, 0.18)
        XCTAssertEqual(PetSpeechBubbleLayout.stackAnimationStaggerDelay, 0.1)
        XCTAssertEqual(PetSpeechBubbleLayout.stackAnimationMaxStaggerDelay, 0.28)
        XCTAssertEqual(PetSpeechBubbleLayout.stackAnimationResponseStep, 0.06)
        XCTAssertEqual(PetSpeechBubbleLayout.stackAnimationDampingStep, 0.018)
        XCTAssertEqual(PetSpeechBubbleLayout.stackAnimationMinimumDampingFraction, 0.68)
        XCTAssertEqual(PetSpeechBubbleLayout.birthPulseDuration, 1.35)
        XCTAssertEqual(PetSpeechBubbleLayout.birthPulseSpringResponse, 0.62)
        XCTAssertEqual(PetSpeechBubbleLayout.birthPulseSpringDampingFraction, 0.82)
        XCTAssertEqual(PetSpeechBubbleLayout.birthPulseFadeOutDuration, 0.5)
        XCTAssertEqual(PetSpeechBubbleLayout.birthPulseOffsetY, 16)
        XCTAssertEqual(PetSpeechBubbleLayout.birthPulseWidth, 112)
        XCTAssertEqual(PetSpeechBubbleLayout.birthPulseHeight, 10)
        XCTAssertEqual(PetSpeechBubbleLayout.contentAnimationDuration, 0.28)
        XCTAssertEqual(PetSpeechBubbleLayout.typewriterCharactersPerSecond, 10)
        XCTAssertEqual(PetSpeechBubbleLayout.typewriterFrameInterval, 1.0 / 30.0)
        XCTAssertEqual(PetSpeechBubbleLayout.organicPrimaryHorizontalJitter, 18)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryHorizontalJitter, 254)
        XCTAssertEqual(PetSpeechBubbleLayout.organicTopRowHorizontalJitter, 286)
        XCTAssertEqual(PetSpeechBubbleLayout.organicPrimaryVerticalJitter, 16)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryVerticalJitter, 92)
        XCTAssertEqual(PetSpeechBubbleLayout.organicTopRowOverlapDrop, 118)
        XCTAssertEqual(PetSpeechBubbleLayout.organicTopRowOverlapJitter, 94)
        XCTAssertEqual(PetSpeechBubbleLayout.organicPrimaryMaximumHorizontalOffset, 20)
        XCTAssertEqual(PetSpeechBubbleLayout.organicPrimaryMinimumVerticalOffset, -8)
        XCTAssertEqual(PetSpeechBubbleLayout.organicPrimaryMaximumVerticalOffset, 18)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryMaximumHorizontalOffset, 220)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryMinimumVerticalOffset, -204)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryMaximumVerticalOffset, -82)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryMinimumDistanceFromMimo, 92)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryMaximumDistanceFromMimo, 222)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryOrbitMinimumAngleDegrees, 22)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryOrbitMaximumAngleDegrees, 158)
        XCTAssertEqual(PetSpeechBubbleLayout.organicPrimaryRotationJitter, 1.4)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryRotationJitter, 7)
        XCTAssertEqual(PetSpeechBubbleLayout.organicPrimaryFloatingHorizontalMaximum, 1.6)
        XCTAssertEqual(PetSpeechBubbleLayout.organicPrimaryFloatingVerticalMaximum, 1.2)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryFloatingHorizontalMaximum, 3.6)
        XCTAssertEqual(PetSpeechBubbleLayout.organicSecondaryFloatingVerticalMaximum, 2.6)
        XCTAssertEqual(PetSpeechBubbleLayout.organicFloatingMinimumDuration, 8.5)
        XCTAssertEqual(PetSpeechBubbleLayout.organicFloatingMaximumDuration, 13.5)
        XCTAssertEqual(PetSpeechBubbleLayout.organicFloatingMaximumDelay, 1.2)
    }

    func testBubbleStackMotionStaggersCardsSoTheyFloatBeforeSettling() {
        let timings = (0..<PetSpeechBubbleLayout.productionVisibleLimit).map {
            PetSpeechBubbleMotionTiming.stackTiming(for: $0)
        }

        zip(timings.map(\.delay), [0, 0.1, 0.2, 0.28]).forEach {
            XCTAssertEqual($0, $1, accuracy: 0.0001)
        }
        XCTAssertEqual(timings[0].response, 0.92, accuracy: 0.0001)
        XCTAssertEqual(timings[1].response, 0.98, accuracy: 0.0001)
        XCTAssertEqual(timings[2].response, 1.04, accuracy: 0.0001)
        XCTAssertEqual(timings[3].response, 1.1, accuracy: 0.0001)
        zip(timings.map(\.dampingFraction), [0.78, 0.762, 0.744, 0.726]).forEach {
            XCTAssertEqual($0, $1, accuracy: 0.0001)
        }
        XCTAssertTrue(zip(timings, timings.dropFirst()).allSatisfy { previous, next in
            next.delay > previous.delay &&
            next.response > previous.response &&
            next.dampingFraction < previous.dampingFraction
        })
    }

    func testBubbleStackMotionClampsTimingToVisibleBubbleRange() {
        let first = PetSpeechBubbleMotionTiming.stackTiming(for: 0)
        let negative = PetSpeechBubbleMotionTiming.stackTiming(for: -4)
        let last = PetSpeechBubbleMotionTiming.stackTiming(for: PetSpeechBubbleLayout.productionVisibleLimit - 1)
        let overflow = PetSpeechBubbleMotionTiming.stackTiming(for: 99)

        XCTAssertEqual(negative, first)
        XCTAssertEqual(overflow, last)
        XCTAssertLessThanOrEqual(overflow.delay, PetSpeechBubbleLayout.stackAnimationMaxStaggerDelay)
        XCTAssertGreaterThanOrEqual(overflow.dampingFraction, PetSpeechBubbleLayout.stackAnimationMinimumDampingFraction)
    }

    func testConversationRowsUseCompactCardShapeForReadableChatNames() {
        XCTAssertEqual(PetSpeechBubbleLayout.chatTitleTextLimit, 34)
        XCTAssertEqual(PetSpeechBubbleLayout.textLimit(for: .conversation), 96)
        XCTAssertEqual(PetSpeechBubbleLayout.titleLineLimit(for: .conversation), 2)
        XCTAssertEqual(PetSpeechBubbleLayout.summaryLineLimit(for: .conversation), 2)
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .conversation), 3)
    }

    func testProductionBubbleWidthsUseCompactReadableColumns() {
        let status = PetSpeechBubbleLayout.placement(for: 0, role: .status, visibleCount: 1)
        let focus = PetSpeechBubbleLayout.placement(for: 0, role: .focus, visibleCount: 3)
        let conversation = PetSpeechBubbleLayout.placement(for: 1, role: .conversation, visibleCount: 3)
        let overflow = PetSpeechBubbleLayout.placement(for: 4, role: .overflow, visibleCount: 5)

        XCTAssertLessThanOrEqual(status.maxTextWidth, PetSpeechBubbleLayout.productionStackWidth * 0.84)
        XCTAssertLessThanOrEqual(focus.maxTextWidth, PetSpeechBubbleLayout.productionStackWidth * 0.84)
        XCTAssertLessThanOrEqual(conversation.maxTextWidth, PetSpeechBubbleLayout.productionStackWidth * 0.43)
        XCTAssertLessThanOrEqual(overflow.maxTextWidth, PetSpeechBubbleLayout.productionStackWidth * 0.36)
        XCTAssertLessThanOrEqual(status.minTextWidth ?? 0, status.maxTextWidth)
        XCTAssertLessThanOrEqual(conversation.minTextWidth ?? 0, conversation.maxTextWidth)
        XCTAssertLessThanOrEqual(overflow.minTextWidth ?? 0, overflow.maxTextWidth)
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
        XCTAssertTrue(placements.dropFirst().allSatisfy { abs($0.horizontalOffset) <= 150 })
    }

    func testOrganicBubblePlacementAddsStableUnevenVariation() {
        let seeds = ["Mimo runtime QA", "資料整理", "リリース準備", "別チャットの確認"]
        let placements = seeds.map {
            PetSpeechBubbleLayout.placement(
                for: 1,
                role: .conversation,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                variationSeed: $0
            )
        }
        let repeated = PetSpeechBubbleLayout.placement(
            for: 1,
            role: .conversation,
            visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
            variationSeed: seeds[0]
        )

        XCTAssertEqual(placements[0], repeated)
        XCTAssertGreaterThanOrEqual(Set(placements.map { Int(($0.maxTextWidth * 10).rounded()) }).count, 3)
        XCTAssertGreaterThanOrEqual(Set(placements.map { Int(($0.horizontalOffset * 10).rounded()) }).count, 3)
        XCTAssertGreaterThanOrEqual(Set(placements.map { Int(($0.fontScale * 1_000).rounded()) }).count, 3)
        XCTAssertGreaterThanOrEqual(Set(placements.map { Int(($0.rotationDegrees * 100).rounded()) }).count, 3)
        XCTAssertTrue(placements.contains { $0.maxTextWidth != 218 })
        XCTAssertTrue(placements.contains { $0.fontScale != 1 })
        XCTAssertTrue(placements.contains { $0.rotationDegrees != 0 })
    }

    func testOrganicPrimaryBubbleStaysNearMimoWhileJittering() {
        let seeds = [
            "Mimo runtime QA",
            "資料整理",
            "リリース準備",
            "別チャットの確認",
            "吹き出し演出",
            "長めのチャット名でサイズ確認"
        ]
        let placements = seeds.map {
            PetSpeechBubbleLayout.placement(
                for: 0,
                role: .focus,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                variationSeed: $0
            )
        }

        XCTAssertTrue(placements.allSatisfy {
            abs($0.horizontalOffset) <= PetSpeechBubbleLayout.organicPrimaryMaximumHorizontalOffset
        })
        XCTAssertTrue(placements.allSatisfy {
            $0.verticalOffset >= PetSpeechBubbleLayout.organicPrimaryMinimumVerticalOffset &&
                $0.verticalOffset <= PetSpeechBubbleLayout.organicPrimaryMaximumVerticalOffset
        })
        XCTAssertTrue(placements.allSatisfy {
            abs($0.rotationDegrees) <= PetSpeechBubbleLayout.organicPrimaryRotationJitter
        })
        XCTAssertTrue(placements.allSatisfy {
            hypot(
                abs($0.horizontalOffset) + abs($0.floatingHorizontalOffset),
                abs($0.verticalOffset) + abs($0.floatingVerticalOffset)
            ) <= 32
        })
        XCTAssertGreaterThanOrEqual(Set(placements.map { Int(($0.horizontalOffset * 10).rounded()) }).count, 3)
        XCTAssertGreaterThanOrEqual(Set(placements.map { Int(($0.verticalOffset * 10).rounded()) }).count, 3)
    }

    func testOrganicBubbleFloatAddsSubtleUnsynchronizedMotion() {
        let seeds = [
            "Mimo runtime QA",
            "資料整理",
            "リリース準備",
            "別チャットの確認",
            "吹き出し演出",
            "長めのチャット名でサイズ確認"
        ]
        let placements = seeds.enumerated().map { index, seed in
            PetSpeechBubbleLayout.placement(
                for: index % PetSpeechBubbleLayout.productionVisibleLimit,
                role: index == 0 ? .focus : .conversation,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                variationSeed: seed
            )
        }

        XCTAssertTrue(placements.allSatisfy { $0.floatingDuration >= PetSpeechBubbleLayout.organicFloatingMinimumDuration })
        XCTAssertTrue(placements.allSatisfy { $0.floatingDuration <= PetSpeechBubbleLayout.organicFloatingMaximumDuration })
        XCTAssertTrue(placements.allSatisfy { $0.floatingDelay >= 0 })
        XCTAssertTrue(placements.allSatisfy { $0.floatingDelay <= PetSpeechBubbleLayout.organicFloatingMaximumDelay })
        XCTAssertTrue(placements.allSatisfy {
            abs($0.floatingHorizontalOffset) <= ($0.index == 0
                ? PetSpeechBubbleLayout.organicPrimaryFloatingHorizontalMaximum
                : PetSpeechBubbleLayout.organicSecondaryFloatingHorizontalMaximum)
        })
        XCTAssertTrue(placements.allSatisfy {
            abs($0.floatingVerticalOffset) <= ($0.index == 0
                ? PetSpeechBubbleLayout.organicPrimaryFloatingVerticalMaximum
                : PetSpeechBubbleLayout.organicSecondaryFloatingVerticalMaximum)
        })
        XCTAssertGreaterThanOrEqual(Set(placements.map { Int(($0.floatingDuration * 10).rounded()) }).count, 4)
        XCTAssertGreaterThanOrEqual(Set(placements.map { Int(($0.floatingDelay * 100).rounded()) }).count, 4)
        XCTAssertGreaterThanOrEqual(Set(placements.map { $0.floatingHorizontalOffset > 0 }).count, 2)
    }

    func testOrganicSecondaryBubblesUseDynamicPocketPileRange() {
        let seeds = [
            "Mimo runtime QA",
            "資料整理",
            "リリース準備",
            "別チャットの確認",
            "吹き出し演出",
            "長めのチャット名でサイズ確認"
        ]
        let placements = seeds.flatMap { seed in
            (1..<PetSpeechBubbleLayout.productionVisibleLimit).map { index in
                PetSpeechBubbleLayout.placement(
                    for: index,
                    role: index == PetSpeechBubbleLayout.productionVisibleLimit - 1 ? .overflow : .conversation,
                    visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                    variationSeed: seed
                )
            }
        }
        let horizontalOffsets = placements.map(\.horizontalOffset)
        let verticalOffsets = placements.map(\.verticalOffset)
        let rotations = placements.map(\.rotationDegrees)

        XCTAssertTrue(placements.allSatisfy {
            abs($0.horizontalOffset) <= PetSpeechBubbleLayout.organicSecondaryMaximumHorizontalOffset
        })
        XCTAssertTrue(placements.allSatisfy {
            $0.verticalOffset >= PetSpeechBubbleLayout.organicSecondaryMinimumVerticalOffset &&
                $0.verticalOffset <= PetSpeechBubbleLayout.organicSecondaryMaximumVerticalOffset
        })
        XCTAssertTrue(placements.allSatisfy {
            abs($0.rotationDegrees) <= PetSpeechBubbleLayout.organicSecondaryRotationJitter
        })
        XCTAssertGreaterThanOrEqual((horizontalOffsets.max() ?? 0) - (horizontalOffsets.min() ?? 0), 200)
        XCTAssertGreaterThanOrEqual((verticalOffsets.max() ?? 0) - (verticalOffsets.min() ?? 0), 90)
        XCTAssertGreaterThanOrEqual((rotations.max() ?? 0) - (rotations.min() ?? 0), 10)
        XCTAssertTrue(placements.contains { $0.horizontalOffset <= -80 })
        XCTAssertTrue(placements.contains { $0.horizontalOffset >= 120 })
        XCTAssertTrue(placements.contains { $0.verticalOffset <= -170 })
        XCTAssertTrue(placements.contains { $0.verticalOffset >= -96 })
        XCTAssertTrue(placements.contains { $0.index == 1 && $0.horizontalOffset > -40 })
        XCTAssertTrue(placements.contains { $0.index == 2 && $0.horizontalOffset < 40 })
        XCTAssertTrue(placements.allSatisfy {
            hypot(
                abs($0.horizontalOffset) + abs($0.floatingHorizontalOffset),
                abs($0.verticalOffset) + abs($0.floatingVerticalOffset)
            ) <= PetSpeechBubbleLayout.organicSecondaryMaximumDistanceFromMimo + 16
        })
    }

    func testOrganicSecondaryBubblesStayNearMimoInsteadOfTopEdgeLabels() {
        let placements = [
            "Mimo runtime QA",
            "資料整理",
            "リリース準備",
            "別チャットの確認",
            "吹き出し演出",
            "長めのチャット名でサイズ確認"
        ].flatMap { seed in
            (1..<PetSpeechBubbleLayout.productionVisibleLimit).map { index in
                PetSpeechBubbleLayout.placement(
                    for: index,
                    role: index == PetSpeechBubbleLayout.productionVisibleLimit - 1 ? .overflow : .conversation,
                    visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                    variationSeed: seed
                )
            }
        }

        XCTAssertTrue(placements.allSatisfy {
            hypot($0.horizontalOffset, $0.verticalOffset) <= PetSpeechBubbleLayout.organicSecondaryMaximumDistanceFromMimo + 0.001
        })
        XCTAssertTrue(placements.allSatisfy { $0.verticalOffset >= PetSpeechBubbleLayout.organicSecondaryMinimumVerticalOffset })
        XCTAssertTrue(placements.allSatisfy { $0.verticalOffset <= PetSpeechBubbleLayout.organicSecondaryMaximumVerticalOffset })
        XCTAssertTrue(placements.contains { $0.verticalOffset >= -96 })
        XCTAssertTrue(placements.contains { abs($0.horizontalOffset) > 100 })
    }

    func testOrganicSecondaryBubblesDoNotCollapseIntoOneHorizontalBand() {
        let placements = (1..<PetSpeechBubbleLayout.productionVisibleLimit).map { index in
            PetSpeechBubbleLayout.placement(
                for: index,
                role: index == PetSpeechBubbleLayout.productionVisibleLimit - 1 ? .overflow : .conversation,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                variationSeed: "Mimo runtime QA"
            )
        }
        let verticalOffsets = placements.map(\.verticalOffset)

        XCTAssertGreaterThanOrEqual((verticalOffsets.max() ?? 0) - (verticalOffsets.min() ?? 0), 36)
        XCTAssertTrue(placements.contains { $0.verticalOffset <= -110 })
        XCTAssertTrue(placements.contains { $0.verticalOffset >= -132 })
    }

    func testOrganicBubblePlacementKeepsIrregularCardsInsideReadableBounds() {
        let seeds = [
            "Mimo runtime QA",
            "資料整理",
            "リリース準備",
            "別チャットの確認",
            "吹き出し演出",
            "長めのチャット名でサイズ確認"
        ]
        let roles: [PetSpeechBubbleRole] = [.focus, .conversation, .overflow]

        for seed in seeds {
            for index in 0..<PetSpeechBubbleLayout.productionVisibleLimit {
                let role = index == 0 ? PetSpeechBubbleRole.focus : roles[index % roles.count]
                let placement = PetSpeechBubbleLayout.placement(
                    for: index,
                    role: role,
                    visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                    variationSeed: seed
                )
                let centerX = PetSpeechBubbleLayout.productionStackWidth / 2 + placement.horizontalOffset
                let halfWidth = placement.maxTextWidth / 2
                let maximumRotation = index == 0 ?
                    PetSpeechBubbleLayout.organicPrimaryRotationJitter :
                    PetSpeechBubbleLayout.organicSecondaryRotationJitter

                XCTAssertGreaterThanOrEqual(centerX - halfWidth, 0)
                XCTAssertLessThanOrEqual(centerX + halfWidth, PetSpeechBubbleLayout.productionStackWidth)
                XCTAssertLessThanOrEqual(placement.minTextWidth ?? 0, placement.maxTextWidth)
                XCTAssertLessThanOrEqual(abs(placement.rotationDegrees), maximumRotation)
                XCTAssertGreaterThanOrEqual(placement.fontScale, index == 0 ? 0.94 : 0.92)
                XCTAssertLessThanOrEqual(placement.fontScale, index == 0 ? 1.12 : 1.14)
                if index == 0 {
                    XCTAssertGreaterThanOrEqual(placement.scale, 0.99)
                    XCTAssertLessThanOrEqual(placement.scale, 1.045)
                    XCTAssertLessThanOrEqual(
                        abs(placement.horizontalOffset),
                        PetSpeechBubbleLayout.organicPrimaryMaximumHorizontalOffset
                    )
                } else {
                    XCTAssertLessThan(placement.scale, 1)
                    XCTAssertLessThanOrEqual(
                        abs(placement.horizontalOffset),
                        PetSpeechBubbleLayout.organicSecondaryMaximumHorizontalOffset
                    )
                    XCTAssertGreaterThanOrEqual(placement.verticalOffset, PetSpeechBubbleLayout.organicSecondaryMinimumVerticalOffset)
                    XCTAssertLessThanOrEqual(placement.verticalOffset, PetSpeechBubbleLayout.organicSecondaryMaximumVerticalOffset)
                    XCTAssertLessThanOrEqual(
                        hypot(
                            abs(placement.horizontalOffset) + abs(placement.floatingHorizontalOffset),
                            abs(placement.verticalOffset) + abs(placement.floatingVerticalOffset)
                        ),
                        PetSpeechBubbleLayout.organicSecondaryMaximumDistanceFromMimo + 16
                    )
                }
            }
        }
    }

    func testOrganicTopRowAllowsControlledOverlapAfterIrregularVariation() {
        let seeds = [
            "Mimo runtime QA",
            "資料整理",
            "リリース準備",
            "別チャットの確認",
            "吹き出し演出",
            "長めのチャット名でサイズ確認"
        ]

        for seed in seeds {
            let left = PetSpeechBubbleLayout.placement(
                for: 1,
                role: .conversation,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                variationSeed: seed
            )
            let right = PetSpeechBubbleLayout.placement(
                for: 2,
                role: .conversation,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                variationSeed: seed
            )
            let top = PetSpeechBubbleLayout.placement(
                for: 3,
                role: .overflow,
                visibleCount: PetSpeechBubbleLayout.productionVisibleLimit,
                variationSeed: seed
            )

            let nearestContextDistance = min(
                abs(top.verticalOffset - left.verticalOffset),
                abs(top.verticalOffset - right.verticalOffset)
            )

            XCTAssertGreaterThanOrEqual(top.verticalOffset, PetSpeechBubbleLayout.organicSecondaryMinimumVerticalOffset)
            XCTAssertLessThanOrEqual(top.verticalOffset, PetSpeechBubbleLayout.organicSecondaryMaximumVerticalOffset)
            XCTAssertLessThanOrEqual(abs(top.horizontalOffset), PetSpeechBubbleLayout.organicSecondaryMaximumHorizontalOffset)
            XCTAssertLessThanOrEqual(nearestContextDistance, 96)
        }
    }
}
