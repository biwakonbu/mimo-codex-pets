import XCTest
@testable import MimoDesktopPetCore

final class CodexConversationFocusTests: XCTestCase {
    func testSelectsLatestLineFromPreferredThread() {
        let lines = [
            line(threadId: "current", text: "古い進捗"),
            line(threadId: "other", text: "別スレッドの新しい進捗"),
            line(threadId: "current", text: "現在スレッドの進捗")
        ]

        XCTAssertEqual(
            CodexConversationFocus.select(from: lines, preferredThreadId: "current")?.text,
            "現在スレッドの進捗"
        )
    }

    func testFallsBackToLatestLineWhenPreferredThreadIsMissing() {
        let lines = [
            line(threadId: "a", text: "A"),
            line(threadId: "b", text: "B")
        ]

        XCTAssertEqual(
            CodexConversationFocus.select(from: lines, preferredThreadId: "missing")?.text,
            "B"
        )
    }

    private func line(threadId: String, text: String) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: threadId,
            speaker: "codex",
            text: text,
            isAssistant: true
        )
    }
}
