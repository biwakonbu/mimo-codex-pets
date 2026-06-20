import XCTest
@testable import MimoDesktopPetCore

final class CodexBubbleFormatterTests: XCTestCase {
    func testSummarizesAssistantLineAsMimoReport() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "実装",
            speaker: "codex",
            text: "レビューできる状態になりました",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "ご主人、「実装」はレビューできます")
    }

    func testSummarizesUserLineAsAcknowledgement() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "実装",
            speaker: "you",
            text: "透明な表示にして",
            isAssistant: false
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "ご主人、「実装」は依頼を確認しました")
    }

    func testSummarizesToolLineWithoutDumpingCommand() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "tool",
            text: "実行: swift test --verbose",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "ご主人、「Mimo runtime QA」はテストを実行中です")
    }

    func testSummarizesStreamingProgressWithoutQuotingDelta() {
        let agent = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Delta QA",
            speaker: "codex",
            text: "応答を作成中",
            isAssistant: true
        )
        let command = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Delta QA",
            speaker: "tool",
            text: "コマンド出力を確認中",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: agent), "ご主人、「Delta QA」は応答をまとめています")
        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: command), "ご主人、「Delta QA」はコマンドを実行中です")
    }

    func testSummarizesActiveWorkFromProgressMessage() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "デスクトップペット品質改善",
            speaker: "codex",
            text: "移動先を決めながら作業しています",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "ご主人、「デスクトップペット品質改善」は作業を進めています")
    }

    func testGenericThreadTitleIsPresentedAsCodex() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Codex Thread",
            speaker: "codex",
            text: "応答を作成中",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "ご主人、「Codex」は応答をまとめています")
    }

    func testCompactsLongBubbleText() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: String(repeating: "長いタイトル", count: 10),
            speaker: "codex",
            text: String(repeating: "長い本文", count: 20),
            isAssistant: true
        )

        let bubble = CodexBubbleFormatter.bubbleText(for: line, limit: 24)

        XCTAssertLessThanOrEqual(bubble.count, 24)
        XCTAssertTrue(bubble.hasSuffix("..."))
    }
}
