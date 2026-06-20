import XCTest
@testable import MimoDesktopPetCore

final class CodexBubbleFormatterTests: XCTestCase {
    func testFormatsAssistantLineForBubble() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "実装",
            speaker: "codex",
            text: "レビューできる状態になりました",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "Codex: レビューできる状態になりました")
    }

    func testFormatsUserLineForBubble() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "実装",
            speaker: "you",
            text: "透明な表示にして",
            isAssistant: false
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "あなた: 透明な表示にして")
    }

    func testCompactsLongBubbleText() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "実装",
            speaker: "codex",
            text: String(repeating: "長い本文", count: 20),
            isAssistant: true
        )

        let bubble = CodexBubbleFormatter.bubbleText(for: line)

        XCTAssertLessThanOrEqual(bubble.count, 42)
        XCTAssertTrue(bubble.hasSuffix("..."))
    }
}
