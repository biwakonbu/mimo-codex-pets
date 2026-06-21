import XCTest
@testable import MimoDesktopPetCore

final class CodexBubbleFormatterTests: XCTestCase {
    func testGeneratedMimoSpeechWinsOverDeterministicSummary() {
        let line = CodexConversationLine(
            threadId: "session-1",
            threadTitle: "Mimo runtime QA",
            speaker: "assistant",
            text: "吹き出し要約を進めています",
            isAssistant: true,
            activityKind: .assistantMessage,
            workSummary: "吹き出し要約の表示文言",
            sessionState: .active,
            mimoSpeech: "ご主人、「Mimo runtime QA」は動作中です。Codex が吹き出し文を整えて、Mimo が分かりやすく伝えます"
        )

        XCTAssertEqual(
            CodexBubbleFormatter.bubbleText(for: line),
            "「Mimo runtime QA」で作業を進めているよ。Codex が吹き出し文を整えて、Mimo が分かりやすく伝えます"
        )
    }

    func testTargetUserSeesChatNameAndWorkInsteadOfInternalCodexStatus() {
        let line = CodexConversationLine(
            threadId: "session-1",
            threadTitle: "UI改善セッション",
            speaker: "assistant",
            text: "吹き出しの文言とアニメーションを調整しています",
            isAssistant: true,
            activityKind: .assistantMessage,
            workSummary: "吹き出し要約の表示文言",
            sessionState: .active,
            mimoSpeech: "ご主人、「UI改善セッション」は動作中です。Codex がチャットの内容を読んで、mimo の言葉に整えています"
        )

        let text = CodexBubbleFormatter.bubbleText(for: line)

        XCTAssertEqual(
            text,
            "「UI改善チャット」で作業を進めているよ。Codex がチャットの内容を読んで、mimo の言葉に整えています"
        )
        XCTAssertFalse(text.contains("ご主人"))
        XCTAssertFalse(text.contains("セッション"))
        XCTAssertFalse(text.contains("スレッド"))
        XCTAssertFalse(text.contains("Codex Session"))
        XCTAssertFalse(text.contains("動作中"))
    }

    func testTargetUserCanScanMultipleChatsByChatNameAndNaturalState() {
        let active = CodexConversationLine(
            threadId: "main",
            threadTitle: "吹き出しUX",
            speaker: "tool",
            text: "テストを実行中",
            isAssistant: true,
            activityKind: .test,
            workSummary: "吹き出し要約の表示文言",
            sessionState: .active
        )
        let waiting = CodexConversationLine(
            threadId: "approval",
            threadTitle: "承認セッション",
            speaker: "thread",
            text: "確認待ち",
            isAssistant: true,
            activityKind: .threadStatus,
            workSummary: "Codex 連携",
            sessionState: .waiting
        )
        let review = CodexConversationLine(
            threadId: "review",
            threadTitle: "レビュー用スレッド",
            speaker: "thread",
            text: "レビュー可能",
            isAssistant: true,
            activityKind: .threadStatus,
            workSummary: "検証",
            sessionState: .stopped
        )

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: CodexBubbleFormatter.bubbleText(for: active),
            conversationLines: [active, waiting, review],
            preferredThreadId: "main",
            primaryThreadId: "main",
            primaryActivityKind: active.activityKind,
            limit: 3
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "「吹き出しUX」は吹き出し要約の表示文言をテスト中だよ",
            "「承認チャット」Codex 連携返事待ち",
            "「レビュー用チャット」検証確認できる"
        ])
        XCTAssertTrue(bubbles.allSatisfy { !$0.text.contains("Codex Session") })
        XCTAssertTrue(bubbles.allSatisfy { !$0.text.contains("セッション") })
        XCTAssertTrue(bubbles.allSatisfy { !$0.text.contains("スレッド") })
        XCTAssertTrue(bubbles.allSatisfy { !$0.text.contains("ご主人") })
    }

    func testSummarizesAssistantLineAsMimoReport() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "実装",
            speaker: "codex",
            text: "レビューできる状態になりました",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "「実装」は確認できるよ")
    }

    func testFormatsSecondaryContextAsShortThreadRow() {
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

        XCTAssertEqual(CodexBubbleFormatter.contextText(for: review), "「実装」確認できる")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: command), "「QA」実行中")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: waiting), "「承認」返事待ち")
    }

    func testSummarizesUserLineAsAcknowledgement() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "実装",
            speaker: "you",
            text: "透明な表示にして",
            isAssistant: false
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "「実装」は表示まわりの依頼を確認したよ")
    }

    func testUserFacingTitleUsesChatVocabulary() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "別スレッドの確認",
            speaker: "codex",
            text: "レビューできる状態になりました",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "「別チャットの確認」は確認できるよ")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: line), "「別チャットの確認」確認できる")
    }

    func testSummarizesSessionContentAsMimoWorkReport() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "codex",
            text: "吹き出しに Codex が作業している内容を要約して状況を説明する実装を進めています",
            isAssistant: true,
            activityKind: .assistantMessage
        )

        XCTAssertEqual(
            CodexBubbleFormatter.bubbleText(for: line),
            "「Mimo runtime QA」は作業内容の説明を進めているよ"
        )
        XCTAssertEqual(
            CodexBubbleFormatter.contextText(for: line),
            "「Mimo runtime...」作業内容の説明中"
        )
    }

    func testUsesInheritedSessionSummaryForToolAndStatusReports() {
        let tool = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "tool",
            text: "テストを実行中",
            isAssistant: true,
            activityKind: .test,
            workSummary: "作業内容の説明"
        )
        let waiting = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "thread",
            text: "確認待ち",
            isAssistant: true,
            activityKind: .threadStatus,
            workSummary: "Codex 連携"
        )
        let genericTool = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "tool",
            text: "ツールを使用中",
            isAssistant: true,
            activityKind: .tool,
            workSummary: "作業内容の説明"
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: tool), "「Mimo runtime QA」は作業内容の説明をテスト中だよ")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: tool), "「Mimo runtime...」作業内容の説明テスト中")
        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: waiting), "「Mimo runtime QA」はCodex 連携で確認を待っているよ")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: waiting), "「Mimo runtime...」Codex 連携返事待ち")
        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: genericTool), "「Mimo runtime QA」は作業内容の説明をツールで確認中だよ")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: genericTool), "「Mimo runtime...」作業内容の説明ツール確認")
    }

    func testSessionStateShapesNaturalMimoReportsWithoutRawStatusLabels() {
        let active = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "tool",
            text: "テストを実行中",
            isAssistant: true,
            activityKind: .test,
            workSummary: "作業内容の説明",
            sessionState: .active
        )
        let stopped = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "thread",
            text: "レビュー可能",
            isAssistant: true,
            activityKind: .threadStatus,
            workSummary: "作業内容の説明",
            sessionState: .stopped
        )

        XCTAssertEqual(
            CodexBubbleFormatter.bubbleText(for: active),
            "「Mimo runtime QA」は作業内容の説明をテスト中だよ"
        )
        XCTAssertEqual(
            CodexBubbleFormatter.contextText(for: active),
            "「Mimo runtime...」作業内容の説明テスト中"
        )
        XCTAssertEqual(
            CodexBubbleFormatter.bubbleText(for: stopped),
            "「Mimo runtime QA」は作業内容の説明を確認できるよ"
        )
        XCTAssertEqual(
            CodexBubbleFormatter.contextText(for: stopped),
            "「Mimo runtime...」作業内容の説明確認できる"
        )
        XCTAssertFalse(CodexBubbleFormatter.bubbleText(for: active).contains("動作中"))
        XCTAssertFalse(CodexBubbleFormatter.contextText(for: stopped).contains("停止・"))
    }

    func testReasoningReportsAsThinkingSummary() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "codex",
            text: "考えを整理中",
            isAssistant: true,
            activityKind: .reasoning,
            workSummary: "吹き出し要約の表示文言",
            sessionState: .active
        )

        XCTAssertEqual(
            CodexBubbleFormatter.bubbleText(for: line),
            "「Mimo runtime QA」は吹き出し要約の表示文言について考えを整理中だよ"
        )
        XCTAssertEqual(
            CodexBubbleFormatter.contextText(for: line),
            "「Mimo runtime...」吹き出し要約の表示文言考察中"
        )
    }

    func testWaitingStateExplainsWorkAndNextActionNaturally() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "tool",
            text: "テストを実行中",
            isAssistant: true,
            activityKind: .test,
            workSummary: "作業内容の説明",
            sessionState: .waiting
        )

        let bubble = CodexBubbleFormatter.bubbleText(for: line)

        XCTAssertEqual(bubble, "「Mimo runtime QA」は作業内容の説明をテスト中で、確認を待っているよ")
        XCTAssertFalse(bubble.contains("だ。確認"))
    }

    func testUnsafeSessionContentDoesNotBecomeVisibleWorkSummary() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "codex",
            text: "/Users/example/private/project/.env の bearer token を吹き出し要約して",
            isAssistant: true,
            activityKind: .assistantMessage
        )

        let bubble = CodexBubbleFormatter.bubbleText(for: line)

        XCTAssertEqual(bubble, "「Mimo runtime QA」は進捗を見つけたよ")
        XCTAssertFalse(bubble.contains("/Users/example"))
        XCTAssertFalse(bubble.contains("token"))
        XCTAssertFalse(bubble.contains(".env"))
    }

    func testSummarizesToolLineWithoutDumpingCommand() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Mimo runtime QA",
            speaker: "tool",
            text: "実行: swift test --verbose",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "「Mimo runtime QA」はテストを実行中だよ")
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

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: testLine), "「Mimo runtime QA」はテストを実行中だよ")
        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: commandLine), "「Mimo runtime QA」はコマンドを実行中だよ")
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

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: terminal), "「端末確認」は端末入力を確認中だよ")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: terminal), "「端末確認」端末確認")
        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: patch), "「差分確認」は差分を確認中だよ")
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
                "「承認」は承認を確認中だよ",
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
                "「承認」は承認を確認したよ",
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
                "「Hook」はフックを確認中だよ",
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
                "「目標」は目標を確認中だよ",
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
                "「確認」は確認を反映中だよ",
                "「確認」確認反映"
            )
        ]

        for (line, expectedPrimary, expectedContext) in cases {
            XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), expectedPrimary)
            XCTAssertEqual(CodexBubbleFormatter.contextText(for: line), expectedContext)
        }
    }

    func testSummarizesSystemProgressNotificationsAsMimoReports() {
        let cases: [(CodexConversationLine, String, String)] = [
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "整理",
                    speaker: "thread",
                    text: "文脈を整理済み",
                    isAssistant: true,
                    activityKind: .contextCompaction
                ),
                "「整理」は文脈を整理したよ",
                "「整理」文脈整理済み"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "モデル",
                    speaker: "thread",
                    text: "モデルを調整中",
                    isAssistant: true,
                    activityKind: .threadStatus
                ),
                "「モデル」はモデルを調整中だよ",
                "「モデル」モデル調整"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "モデル確認",
                    speaker: "thread",
                    text: "モデルを確認中",
                    isAssistant: true,
                    activityKind: .threadStatus
                ),
                "「モデル確認」はモデルを確認中だよ",
                "「モデル確認」モデル確認"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "安全",
                    speaker: "thread",
                    text: "安全を確認中",
                    isAssistant: true,
                    activityKind: .threadStatus
                ),
                "「安全」は安全を確認中だよ",
                "「安全」安全確認"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "問題",
                    speaker: "thread",
                    text: "問題を確認中",
                    isAssistant: true,
                    activityKind: .threadStatus
                ),
                "「問題」は問題を確認中だよ",
                "「問題」問題確認"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "MCP",
                    speaker: "tool",
                    text: "MCP を確認中",
                    isAssistant: true,
                    activityKind: .tool
                ),
                "「MCP」はMCP を確認中だよ",
                "「MCP」MCP 確認"
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

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: agent), "「Delta QA」は応答をまとめているよ")
        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: command), "「Delta QA」はコマンドを実行中だよ")
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
                "「調査」は調査中だよ"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "画像QA",
                    speaker: "tool",
                    text: "画像を生成中",
                    isAssistant: true
                ),
                "「画像QA」は画像を作成中だよ"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "レビュー",
                    speaker: "codex",
                    text: "レビューを開始",
                    isAssistant: true
                ),
                "「レビュー」はレビュー中だよ"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "整理",
                    speaker: "codex",
                    text: "文脈を整理中",
                    isAssistant: true
                ),
                "「整理」は文脈を整理中だよ"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "ブラウザ確認",
                    speaker: "tool",
                    text: "ページ内を検索中",
                    isAssistant: true
                ),
                "「ブラウザ確認」はページを確認中だよ"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "スキル確認",
                    speaker: "tool",
                    text: "スキルを確認中",
                    isAssistant: true
                ),
                "「スキル確認」はスキルを確認中だよ"
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
                "「計画」は計画を整理中だよ"
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
                "「ファイル確認」はファイルを確認中だよ"
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
                "「参照」は参照を確認中だよ"
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

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "「テスト」はつまずいたところを見つけたよ")
        XCTAssertEqual(CodexBubbleFormatter.contextText(for: line), "「テスト」つまずきあり")
    }

    func testSummarizesActiveWorkFromProgressMessage() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "デスクトップペット品質改善",
            speaker: "codex",
            text: "移動先を決めながら作業しています",
            isAssistant: true
        )

        XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), "「デスクトップペット品質改善」はMimo の動きを進めているよ")
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
                "「状態だけのチャット」は作業を進めているよ"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "承認待ち",
                    speaker: "thread",
                    text: "確認待ち",
                    isAssistant: true
                ),
                "「承認待ち」は確認を待っているよ"
            ),
            (
                CodexConversationLine(
                    threadId: "thread",
                    threadTitle: "レビュー",
                    speaker: "thread",
                    text: "レビュー可能",
                    isAssistant: true
                ),
                "「レビュー」は確認できるよ"
            )
        ]

        for (line, expected) in cases {
            XCTAssertEqual(CodexBubbleFormatter.bubbleText(for: line), expected)
        }
    }

    func testGenericThreadTitleIsPresentedAsReadableChatFallback() {
        let line = CodexConversationLine(
            threadId: "thread",
            threadTitle: "Codex Thread",
            speaker: "codex",
            text: "応答を作成中",
            isAssistant: true
        )

        let bubble = CodexBubbleFormatter.bubbleText(for: line)
        XCTAssertEqual(bubble, "「このチャット」は応答をまとめているよ")
        XCTAssertFalse(bubble.contains("Codex Session"))
        XCTAssertFalse(bubble.contains("Codex Thread"))
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

            XCTAssertEqual(bubble, "「このチャット」は応答をまとめているよ")
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

        XCTAssertEqual(bubble, "「このチャット」応答中")
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
