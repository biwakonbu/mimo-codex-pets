import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleAccessibilityTests: XCTestCase {
    func testProductionAccessibilityValueUsesVisibleBubbleText() {
        let value = PetSpeechBubbleAccessibility.value(
            presentation: PetPresentationState(animation: .running, bubbleText: CodexMimoStatusSpeech.active),
            bubbles: [
                PetSpeechBubble(
                    id: "primary",
                    text: "「実装」は作業を進めているよ",
                    role: .focus,
                    tone: .active,
                    activityKind: .assistantMessage
                ),
                PetSpeechBubble(
                    id: "secondary",
                    text: "「QA」返事待ちだよ",
                    role: .conversation,
                    tone: .waiting,
                    activityKind: .threadStatus
                )
            ],
            debugOverlay: false
        )

        XCTAssertEqual(
            value,
            "本番表示。running。「実装」は作業を進めているよ / 「QA」返事待ちだよ"
        )
    }

    func testAccessibilityValueDoesNotRepeatExplicitThreadTitle() {
        let value = PetSpeechBubbleAccessibility.value(
            presentation: PetPresentationState(animation: .running, bubbleText: "作業中"),
            bubbles: [
                PetSpeechBubble(
                    id: "primary",
                    text: "「主作業」は作業を進めているよ",
                    role: .focus,
                    tone: .active,
                    activityKind: .assistantMessage,
                    threadId: "main",
                    threadTitle: "主作業"
                )
            ],
            debugOverlay: false
        )

        XCTAssertEqual(value, "本番表示。running。「主作業」は作業を進めているよ")
    }

    func testDebugAccessibilityValueMarksDebugMode() {
        let value = PetSpeechBubbleAccessibility.value(
            presentation: PetPresentationState(animation: .idle, bubbleText: CodexMimoStatusSpeech.idle),
            bubbles: [
                PetSpeechBubble(id: "idle", text: CodexMimoStatusSpeech.idle, role: .status)
            ],
            debugOverlay: true
        )

        XCTAssertEqual(value, "デバッグ表示。idle。いまはのんびり待ってるよ")
    }

    func testAccessibilityValueKeepsProductionVisibleLimit() {
        let bubbles = (0..<(PetSpeechBubbleLayout.productionVisibleLimit + 2)).map { index in
            PetSpeechBubble(
                id: "\(index)",
                text: "bubble-\(index)",
                role: index == 0 ? .focus : .conversation
            )
        }

        let value = PetSpeechBubbleAccessibility.value(
            presentation: PetPresentationState(animation: .review, bubbleText: "確認してよさそう"),
            bubbles: bubbles,
            debugOverlay: false
        )

        XCTAssertTrue(value.contains("bubble-0"))
        XCTAssertTrue(value.contains("bubble-\(PetSpeechBubbleLayout.productionVisibleLimit - 1)"))
        XCTAssertFalse(value.contains("bubble-\(PetSpeechBubbleLayout.productionVisibleLimit)"))
    }

    func testBubbleAccessibilityIdentifiersAndLabelsAreStable() {
        XCTAssertEqual(
            PetSpeechBubbleAccessibility.bubbleIdentifier(index: 0, role: .focus),
            "MimoDesktopPet.productionSurface.bubble.0.focus"
        )
        XCTAssertEqual(
            PetSpeechBubbleAccessibility.bubbleIdentifier(index: 4, role: .overflow),
            "MimoDesktopPet.productionSurface.bubble.4.overflow"
        )
        XCTAssertEqual(
            PetSpeechBubbleAccessibility.bubbleLabel(index: 0, role: .focus),
            "Mimoが伝える主なチャット 1"
        )
        XCTAssertEqual(
            PetSpeechBubbleAccessibility.bubbleLabel(index: 4, role: .overflow),
            "Mimoが見ているほかのチャット 5"
        )
        XCTAssertEqual(
            PetSpeechBubbleAccessibility.bubbleElementLabel(
                index: 0,
                role: .focus,
                text: "「実装」は作業中だよ"
            ),
            "Mimoが伝える主なチャット 1: 「実装」は作業中だよ"
        )
        XCTAssertGreaterThan(
            PetSpeechBubbleAccessibility.bubbleSortPriority(index: 0),
            PetSpeechBubbleAccessibility.bubbleSortPriority(index: 1)
        )
        XCTAssertGreaterThan(
            PetSpeechBubbleAccessibility.bubbleSortPriority(index: 3),
            PetSpeechBubbleAccessibility.bubbleSortPriority(index: 4)
        )
    }
}
