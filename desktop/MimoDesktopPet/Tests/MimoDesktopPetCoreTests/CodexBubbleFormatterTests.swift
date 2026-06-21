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

    func testFormatsSecondaryContextAsShortThreadChip() {
        let review = CodexConversationLine(
            threadId: "thread",
            threadTitle: "実装",
            speaker: "codex",
            text: "レビューできる状態になりました",
            isAssistant: true
        )
        let command = CodexConversationLine(
            threadId: "thread",
            threadTitle: "QA",
            speaker: "tool",
            text: "コマンドを実行中",
            isAssistant: true
        )
        let waiting = CodexConversationLine(
            threadId: "thread",
            threadTitle: "承認",
            speaker: "thread",
            text: "確認待ち",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.contextText(for: review), "「実装」レビュー可")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: command), "「QA」実行中")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: waiting), "「承認」確認待ち")
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

    func testSummarizesTerminalAndPatchProgressAsMimoReports() {
        let terminal = CodexConversationLine(
            threadId: "thread",
            threadTitle: "端末確認",
            speaker: "tool",
            text: "端末入力を確認中",
            isAssistant: true,
            activityKind: .command
        )
        let patch = CodexConversationLine(
            threadId: "thread",
            threadTitle: "差分確認",
            speaker: "tool",
            text: "変更差分を確認中",
            isAssistant: true,
            activityKind: .fileChange
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: terminal), "ご主人、「端末確認」は端末入力を確認中です")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: terminal), "「端末確認」端末確認")
        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: patch), "ご主人、「差分確認」は差分を確認中です")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: patch), "「差分確認」差分確認")
    }

    func testSummarizesExpandedProgressNotificationsAsMimoReports() {
        let cases: [(CodexConversationLine, String, String)] = [
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "承認",
                    speaker: "tool",
                    text: "承認を確認中",
                    isAssistant: true,
                    activityKind: .review
                ),
                "ご主人、「承認」は承認を確認中です",
                "「承認」承認確認"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "承認",
                    speaker: "tool",
                    text: "承認確認済み",
                    isAssistant: true,
                    activityKind: .review
                ),
                "ご主人、「承認」は承認を確認しました",
                "「承認」承認確認済み"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "Hook",
                    speaker: "tool",
                    text: "フックを確認中",
                    isAssistant: true,
                    activityKind: .tool
                ),
                "ご主人、「Hook」はフックを確認中です",
                "「Hook」フック確認"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "目標",
                    speaker: "thread",
                    text: "目標を確認中",
                    isAssistant: true,
                    activityKind: .threadStatus
                ),
                "ご主人、「目標」は目標を確認中です",
                "「目標」目標確認"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "確認",
                    speaker: "thread",
                    text: "確認を反映中",
                    isAssistant: true,
                    activityKind: .threadStatus
                ),
                "ご主人、「確認」は確認を反映中です",
                "「確認」確認反映"
            )
        ]

        for (line, expectedPrimary, expectedContext) in cases {
            XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), expectedPrimary)
            XCTAssertEqual(CodexBubbleFormatter.contextText(for: line), expectedContext)
        }
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

    func testUsesActivityKindBeforeLooseTextGuessing() {
        let cases: [(CodexConversationLine, String)] = [
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "計画",
                    speaker: "codex",
                    text: "表示を確認しました",
                    isAssistant: true,
                    activityKind: .plan
                ),
                "ご主人、「計画」は計画を整理中です"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "ファイル確認",
                    speaker: "tool",
                    text: "ファイルを確認中",
                    isAssistant: true,
                    activityKind: .fileRead
                ),
                "ご主人、「ファイル確認」はファイルを確認中です"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "参照",
                    speaker: "thread",
                    text: "参照を確認中",
                    isAssistant: true,
                    activityKind: .mention
                ),
                "ご主人、「参照」は参照を確認中です"
            )
        ]

        for (line, expected) in cases {
            XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), expected)
        }
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: cases[1].0), "「ファイル確認」ファイル確認")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: cases[2].0), "「参照」参照確認")
    }

    func testFailedTextStillOverridesActivityKind() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "テスト",
            speaker: "tool",
            text: "テスト実行に失敗",
            isAssistant: true,
            activityKind: .test
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "ご主人、「テスト」は失敗を確認しました")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: line), "「テスト」失敗")
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

    func testSensitiveThreadTitleIsPresentedAsCodex() {
        let cases = [
            "/Users/example/private/project/.env",
            "https://example.com/private-token",
            "secret token 0123456789abcdef0123456789abcdef",
            "user@example.com の設定"
        ]

        for title in cases {
            let bubble = CodexBubbleFormatter.bubbleText(
                for: CodexConversationLine(
                    threadId: "thread",
                    threadTitle: title,
                    speaker: "codex",
                    text: "応答を作成中",
                    isAssistant: true
                )
            )

            XCTAssertEqual(bubble, "ご主人、「Codex」は応答をまとめています")
            XCTAssertFalse(bubble.contains("/Users/example"))
            XCTAssertFalse(bubble.contains("example.com"))
            XCTAssertFalse(bubble.contains("secret"))
            XCTAssertFalse(bubble.contains("@"))
        }
    }

    func testSecondaryContextKeepsUnsafeTitleOutOfAmbientDisplay() {
        let bubble = CodexBubbleFormatter.contextText(
            for: CodexConversationLine(
                threadId: "thread",
                threadTitle: "/Users/example/private/project/.env",
                speaker: "codex",
                text: "応答を作成中",
                isAssistant: true
            )
        )

        XCTAssertEqual(bubble, "「Codex」応答中")
        XCTAssertFalse(bubble.contains("/Users/example"))
        XCTAssertFalse(bubble.contains(".env"))
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
