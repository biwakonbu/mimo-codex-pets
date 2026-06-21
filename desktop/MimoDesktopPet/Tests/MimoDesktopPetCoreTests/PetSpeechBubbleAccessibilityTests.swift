import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleAccessibilityTests: XCTestCase {
    func testProductionAccessibilityValueUsesVisibleBubbleText() {
        let value = PetSpeechBubbleAccessibility.value(
            presentation: PetPresentationState(animation: .running, bubbleText: "Codex が作業中"),
            bubbles: [
                PetSpeechBubble(
                    id: "primary",
                    text: "ご主人、「実装」は作業を進めています",
                    role: .focus,
                    tone: .active,
                    activityKind: .assistantMessage
                ),
                PetSpeechBubble(
                    id: "secondary",
                    text: "「QA」確認待ち",
                    role: .conversation,
                    tone: .waiting,
                    activityKind: .threadStatus
                )
            ],
            debugOverlay: false
        )

        XCTAssertEqual(
            value,
            "本番表示。running。ご主人、「実装」は作業を進めています / 「QA」確認待ち"
        )
    }

    func testDebugAccessibilityValueMarksDebugMode() {
        let value = PetSpeechBubbleAccessibility.value(
            presentation: PetPresentationState(animation: .idle, bubbleText: "待機中"),
            bubbles: [
                PetSpeechBubble(id: "idle", text: "待機中", role: .status)
            ],
            debugOverlay: true
        )

        XCTAssertEqual(value, "デバッグ表示。idle。待機中")
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
            presentation: PetPresentationState(animation: .review, bubbleText: "レビューできます"),
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
            "Mimo primary thread bubble 1"
        )
        XCTAssertEqual(
            PetSpeechBubbleAccessibility.bubbleLabel(index: 4, role: .overflow),
            "Mimo overflow bubble 5"
        )
        XCTAssertEqual(
            PetSpeechBubbleAccessibility.bubbleElementLabel(
                index: 0,
                role: .focus,
                text: "ご主人、「実装」は作業中です"
            ),
            "Mimo primary thread bubble 1: ご主人、「実装」は作業中です"
        )
    }
}
