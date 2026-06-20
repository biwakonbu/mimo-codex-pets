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

    func testSummarizesSanitizedCommandActivityWithoutRawCommandText() {
        let testLine = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "tool",
            text: "テストを実行中",
            isAssistant: true
        )
        let commandLine = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "tool",
            text: "コマンドを実行中",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: testLine), "ご主人、「Mimo runtime QA」はテストを実行中です")
        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: commandLine), "ご主人、「Mimo runtime QA」はコマンドを実行中です")
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

    func testSummarizesExpandedSchemaActivityKinds() {
        let cases: [(CodexConversationLine, String)] = [
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "調査",
                    speaker: "tool",
                    text: "Web 検索中",
                    isAssistant: true
                ),
                "ご主人、「調査」は調査中です"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "画像QA",
                    speaker: "tool",
                    text: "画像を生成中",
                    isAssistant: true
                ),
                "ご主人、「画像QA」は画像を作成中です"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "レビュー",
                    speaker: "codex",
                    text: "レビューを開始",
                    isAssistant: true
                ),
                "ご主人、「レビュー」はレビュー中です"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "整理",
                    speaker: "codex",
                    text: "文脈を整理中",
                    isAssistant: true
                ),
                "ご主人、「整理」は文脈を整理中です"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "ブラウザ確認",
                    speaker: "tool",
                    text: "ページ内を検索中",
                    isAssistant: true
                ),
                "ご主人、「ブラウザ確認」はページを確認中です"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "スキル確認",
                    speaker: "tool",
                    text: "スキルを確認中",
                    isAssistant: true
                ),
                "ご主人、「スキル確認」はスキルを確認中です"
            )
        ]

        for (line, expected) in cases {
            XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), expected)
        }
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

    func testSummarizesThreadStatusLines() {
        let cases: [(CodexConversationLine, String)] = [
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "状態だけのスレッド",
                    speaker: "thread",
                    text: "作業中",
                    isAssistant: true
                ),
                "ご主人、「状態だけのスレッド」は作業を進めています"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "承認待ち",
                    speaker: "thread",
                    text: "確認待ち",
                    isAssistant: true
                ),
                "ご主人、「承認待ち」は確認待ちです"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "レビュー",
                    speaker: "thread",
                    text: "レビュー可能",
                    isAssistant: true
                ),
                "ご主人、「レビュー」はレビューできます"
            )
        ]

        for (line, expected) in cases {
            XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), expected)
        }
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
