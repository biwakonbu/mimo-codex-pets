import XCTest
@testable import MimoDesktopPetCore

final class CodexMimoDialogueSchedulerTests: XCTestCase {
    func testCachedFocusedThreadDoesNotBlockSecondaryThreadGeneration() {
        let focused = line(threadId: "focused", title: "主作業")
        let secondary = line(threadId: "secondary", title: "資料整理")
        let focusedKey = CodexMimoDialoguePrompt.cacheKey(for: focused)

        let candidate = CodexMimoDialogueScheduler.nextCandidate(
            from: [secondary, focused],
            preferredThreadId: "focused",
            excludedKeys: [focusedKey],
            throttledThreadIds: []
        )

        XCTAssertEqual(candidate?.threadId, "secondary")
    }

    func testPendingAndThrottledThreadsAreSkipped() {
        let first = line(threadId: "first", title: "主作業")
        let second = line(threadId: "second", title: "資料整理")

        let candidate = CodexMimoDialogueScheduler.nextCandidate(
            from: [second, first],
            preferredThreadId: "first",
            excludedKeys: [CodexMimoDialoguePrompt.cacheKey(for: first)],
            throttledThreadIds: ["second"]
        )

        XCTAssertNil(candidate)
    }

    private func line(threadId: String, title: String) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: title,
            speaker: "codex",
            text: "作業を進めています",
            isAssistant: true,
            activityKind: .assistantMessage,
            workSummary: "吹き出し表示の改善",
            sessionState: .active
        )
    }
}
