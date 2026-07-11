import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleHitTestingTests: XCTestCase {
    func testPrimaryCardClickReturnsPrimaryThreadBubble() {
        let primary = bubble(
            id: "primary",
            role: .focus,
            threadId: "current",
            threadTitle: "Mimo UI 改善"
        )
        let target = PetSpeechBubbleHitTesting.openableBubble(
            at: PetWanderPoint(x: 260, y: 230),
            bubbles: [primary],
            framesByBubbleId: [primary.id: PetDragFrame(x: 80, y: 180, width: 360, height: 100)]
        )

        XCTAssertEqual(target?.threadId, "current")
        XCTAssertEqual(target?.threadTitle, "Mimo UI 改善")
    }

    func testSecondaryCardClickReturnsThatThreadBubble() {
        let primary = bubble(
            id: "primary",
            role: .focus,
            threadId: "current",
            threadTitle: "Mimo UI 改善"
        )
        let secondary = bubble(
            id: "secondary",
            role: .conversation,
            threadId: "docs",
            threadTitle: "Docs 更新"
        )
        let target = PetSpeechBubbleHitTesting.openableBubble(
            at: PetWanderPoint(x: 130, y: 390),
            bubbles: [primary, secondary],
            framesByBubbleId: [
                primary.id: PetDragFrame(x: 80, y: 180, width: 360, height: 100),
                secondary.id: PetDragFrame(x: 40, y: 350, width: 190, height: 80)
            ]
        )

        XCTAssertEqual(target?.threadId, "docs")
        XCTAssertEqual(target?.threadTitle, "Docs 更新")
    }

    func testStatusBubbleWithoutThreadIsNotOpenable() {
        let status = PetSpeechBubble(
            id: "status",
            text: CodexMimoStatusSpeech.idle,
            role: .status
        )

        let target = PetSpeechBubbleHitTesting.openableBubble(
            at: PetWanderPoint(x: 260, y: 230),
            bubbles: [status],
            framesByBubbleId: [status.id: PetDragFrame(x: 80, y: 180, width: 360, height: 100)]
        )

        XCTAssertNil(target)
    }

    func testBlankSpaceInsideFormerStackBoundsDoesNotOpenPrimaryThread() {
        let primary = bubble(
            id: "primary",
            role: .focus,
            threadId: "current",
            threadTitle: "Mimo UI 改善"
        )

        let target = PetSpeechBubbleHitTesting.openableBubble(
            at: PetWanderPoint(x: 20, y: 430),
            bubbles: [primary],
            framesByBubbleId: [primary.id: PetDragFrame(x: 80, y: 180, width: 360, height: 100)]
        )

        XCTAssertNil(target)
    }

    func testOverlappingCardsPreferFrontmostVisibleBubble() {
        let primary = bubble(id: "primary", role: .focus, threadId: "primary-thread", threadTitle: "主作業")
        let secondary = bubble(id: "secondary", role: .conversation, threadId: "secondary-thread", threadTitle: "資料整理")
        let sharedPoint = PetWanderPoint(x: 180, y: 220)

        let target = PetSpeechBubbleHitTesting.openableBubble(
            at: sharedPoint,
            bubbles: [primary, secondary],
            framesByBubbleId: [
                primary.id: PetDragFrame(x: 80, y: 180, width: 300, height: 100),
                secondary.id: PetDragFrame(x: 120, y: 190, width: 200, height: 80)
            ]
        )

        XCTAssertEqual(target?.threadId, "primary-thread")
    }

    private func bubble(
        id: String,
        role: PetSpeechBubbleRole,
        threadId: String,
        threadTitle: String
    ) -> PetSpeechBubble {
        PetSpeechBubble(
            id: id,
            text: "「\(threadTitle)」進めてるよ",
            role: role,
            tone: .active,
            activityKind: .assistantMessage,
            threadId: threadId,
            threadTitle: threadTitle
        )
    }

}
