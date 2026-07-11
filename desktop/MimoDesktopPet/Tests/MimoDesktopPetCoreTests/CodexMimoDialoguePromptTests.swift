import XCTest
@testable import MimoDesktopPetCore

final class CodexMimoDialoguePromptTests: XCTestCase {
    func testDialogueDefaultsUseLunaAtLowReasoningEffort() {
        XCTAssertEqual(CodexMimoDialoguePrompt.defaultModel, "gpt-5.6-luna")
        XCTAssertEqual(CodexMimoDialoguePrompt.defaultReasoningEffort, "low")
        XCTAssertEqual(CodexMimoDialoguePrompt.defaultRefreshIntervalSeconds, 30 * 60.0)
    }

    func testPromptUsesOnlySafeChatFields() {
        let line = CodexConversationLine(
            threadId: "session-1",
            threadTitle: "Mimo runtime QA",
            speaker: "assistant",
            text: "/Users/example/private/.env Authorization: Bearer abcdef0123456789abcdef",
            isAssistant: true,
            activityKind: .reasoning,
            workSummary: "吹き出し要約の表示文言",
            sessionState: .active
        )

        let prompt = CodexMimoDialoguePrompt.userInput(for: line)

        XCTAssertTrue(prompt.contains("chat_name: Mimo runtime QA"))
        XCTAssertTrue(prompt.contains("chat_state: 作業を進めている"))
        XCTAssertTrue(prompt.contains("safe_work_topic: 吹き出し要約の表示文言"))
        XCTAssertTrue(prompt.contains("recommended_next_step: 作業が続いているので、このチャットを見守る"))
        XCTAssertFalse(prompt.contains("session_name:"))
        XCTAssertFalse(prompt.contains("session_state:"))
        XCTAssertFalse(prompt.contains("/Users/example"))
        XCTAssertFalse(prompt.contains("Authorization"))
        XCTAssertFalse(prompt.contains("Bearer"))
    }

    func testRecommendedNextStepExplainsHowToHandleCompletedChat() {
        let line = CodexConversationLine(
            threadId: "completed-1",
            threadTitle: "資料作成",
            speaker: "thread",
            text: "確認してよさそう",
            isAssistant: true,
            activityKind: .threadStatus,
            sessionState: .stopped
        )

        XCTAssertEqual(
            CodexMimoDialoguePrompt.recommendedNextStep(for: line),
            "内容を確認したらチャットを閉じ、続きが必要なら再開する"
        )
    }

    func testGeneratedStoppedSpeechGetsAConcreteNextAction() {
        let line = CodexConversationLine(
            threadId: "completed-1",
            threadTitle: "資料作成",
            speaker: "thread",
            text: "完了",
            isAssistant: true,
            activityKind: .threadStatus,
            sessionState: .stopped
        )

        XCTAssertEqual(
            CodexMimoDialoguePrompt.addRecommendedNextStep(
                to: "「資料作成」はひと段落したよ",
                for: line
            ),
            "「資料作成」はひと段落したよ。確認後はチャットを閉じて、続きがあれば再開してね"
        )
    }

    func testGeneratedStoppedSpeechDoesNotRepeatAnExistingNextAction() {
        let line = CodexConversationLine(
            threadId: "completed-1",
            threadTitle: "資料作成",
            speaker: "thread",
            text: "完了",
            isAssistant: true,
            activityKind: .threadStatus,
            sessionState: .stopped
        )
        let speech = "「資料作成」は確認後に閉じて、必要なら再開してね"

        XCTAssertEqual(
            CodexMimoDialoguePrompt.addRecommendedNextStep(to: speech, for: line),
            speech
        )
    }

    func testPromptIncludesConcreteSafeRecentProgressClues() {
        let current = CodexConversationLine(
            threadId: "session-1",
            threadTitle: "Mimo UX 改善",
            speaker: "thread",
            text: "作業中",
            isAssistant: true,
            activityKind: .threadStatus,
            workSummary: "吹き出し要約の具体説明",
            sessionState: .active
        )
        let recent = [
            CodexConversationLine(
                threadId: "session-1",
                threadTitle: "Mimo UX 改善",
                speaker: "codex",
                text: "吹き出しの配置差分を調査しています",
                isAssistant: true,
                activityKind: .reasoning,
                workSummary: "吹き出し配置の差分調査"
            ),
            CodexConversationLine(
                threadId: "session-1",
                threadTitle: "Mimo UX 改善",
                speaker: "tool",
                text: "テストを実行中",
                isAssistant: true,
                activityKind: .test,
                workSummary: "クリック領域の回帰テスト"
            ),
            CodexConversationLine(
                threadId: "other",
                threadTitle: "別チャット",
                speaker: "codex",
                text: "この情報は混ぜない",
                isAssistant: true,
                activityKind: .assistantMessage
            )
        ]

        let prompt = CodexMimoDialoguePrompt.userInput(for: current, recentLines: recent)

        XCTAssertTrue(prompt.contains("recent_progress_1: 考えの整理: 吹き出し配置の差分調査"))
        XCTAssertTrue(prompt.contains("recent_progress_2: テスト: クリック領域の回帰テスト"))
        XCTAssertFalse(prompt.contains("この情報は混ぜない"))
    }

    func testPromptDoesNotForwardUnsafeRecentProgressText() {
        let current = CodexConversationLine(
            threadId: "session-1",
            threadTitle: "安全確認",
            speaker: "thread",
            text: "作業中",
            isAssistant: true,
            activityKind: .threadStatus,
            sessionState: .active
        )
        let unsafe = CodexConversationLine(
            threadId: "session-1",
            threadTitle: "安全確認",
            speaker: "codex",
            text: "/Users/example/private/.env Authorization: Bearer abcdef0123456789abcdef",
            isAssistant: true,
            activityKind: .reasoning
        )

        let prompt = CodexMimoDialoguePrompt.userInput(for: current, recentLines: [unsafe])

        XCTAssertTrue(prompt.contains("recent_progress_1: 考えの整理: 考えの整理"))
        XCTAssertFalse(prompt.contains("/Users/example"))
        XCTAssertFalse(prompt.contains("Authorization"))
        XCTAssertFalse(prompt.contains("Bearer"))
    }

    func testSanitizedSpeechRejectsUnsafeGeneratedText() {
        XCTAssertNil(
            CodexMimoDialoguePrompt.sanitizedSpeech(
                from: "ご主人、/Users/example/private/.env の token を確認しました"
            )
        )
    }

    func testSanitizedSpeechUsesChatVocabularyAndDoesNotForceOwnerPrefix() {
        let speech = CodexMimoDialoguePrompt.sanitizedSpeech(
            from: "ご主人、「別スレッド」は動作中です。Codex が進捗を整理しています"
        )

        XCTAssertEqual(speech, "「別チャット」で作業を進めているよ。Codex が進捗を整理しています")
    }

    func testSanitizedSpeechNormalizesTitleQuotes() {
        let speech = CodexMimoDialoguePrompt.sanitizedSpeech(
            from: "ご主人、『Live Mimo Dialogue Smoke』は動作中で、会話生成を確認しています。"
        )

        XCTAssertEqual(speech, "「Live Mimo Dialogue Smoke」で作業を進めていて、会話生成を確認しています。")
    }

    func testSanitizedSpeechRemovesRawStatePrefixes() {
        let speech = CodexMimoDialoguePrompt.sanitizedSpeech(
            from: "動作中・「UI改善セッション」は吹き出しの説明を整えています。"
        )

        XCTAssertEqual(speech, "「UI改善チャット」は吹き出しの説明を整えています。")
    }

    func testSanitizedSpeechRewritesStoppedReviewStatus() {
        let speech = CodexMimoDialoguePrompt.sanitizedSpeech(
            from: "停止・レビュー可「UI改善セッション」は吹き出しを見直せます。"
        )

        XCTAssertEqual(speech, "「UI改善チャット」は吹き出しを見直せます。")
        XCTAssertFalse(speech?.contains("停止") ?? true)
        XCTAssertFalse(speech?.contains("レビュー可") ?? true)
    }

    func testSanitizedSpeechTurnsTechnicalTrackingLanguageIntoMimoNarration() {
        let speech = CodexMimoDialoguePrompt.sanitizedSpeech(
            from: "「UI改善」では配置を見直しているよ。いまはチャット状態: 確認待ちまで見えていて、Codex のいまの様子をMimoも追いかけてるね"
        )

        XCTAssertEqual(
            speech,
            "「UI改善」では配置を見直しているよ。いまは確認待ちまで見えていて、Mimoもそっと見守ってるよ"
        )
        XCTAssertFalse(speech?.contains("チャット状態") ?? true)
    }
}
