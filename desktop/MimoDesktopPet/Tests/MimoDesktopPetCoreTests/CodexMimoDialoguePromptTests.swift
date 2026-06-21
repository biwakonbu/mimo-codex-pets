import XCTest
@testable import MimoDesktopPetCore

final class CodexMimoDialoguePromptTests: XCTestCase {
    func testPromptUsesOnlySafeSessionFields() {
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

        XCTAssertTrue(prompt.contains("session_name: Mimo runtime QA"))
        XCTAssertTrue(prompt.contains("session_state: 動作中"))
        XCTAssertTrue(prompt.contains("safe_work_topic: 吹き出し要約の表示文言"))
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

    func testSanitizedSpeechUsesSessionVocabulary() {
        let speech = CodexMimoDialoguePrompt.sanitizedSpeech(
            from: "ご主人、「別スレッド」は動作中です。Codex が進捗を整理しています"
        )

        XCTAssertEqual(speech, "ご主人、「別セッション」は動作中です。Codex が進捗を整理しています")
    }
}
