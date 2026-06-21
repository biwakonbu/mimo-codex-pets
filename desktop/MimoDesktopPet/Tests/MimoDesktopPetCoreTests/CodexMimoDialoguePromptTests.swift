import XCTest
@testable import MimoDesktopPetCore

final class CodexMimoDialoguePromptTests: XCTestCase {
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
        XCTAssertFalse(prompt.contains("session_name:"))
        XCTAssertFalse(prompt.contains("session_state:"))
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
}
