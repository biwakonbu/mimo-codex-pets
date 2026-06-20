import XCTest
@testable import MimoDesktopPetCore

final class CodexConversationBubblePlannerTests: XCTestCase {
    func testOrdersLatestLinePerThreadWithPreferredThreadFirst() {
        let lines = [
            line(threadId: "current", speaker: "codex", text: "古い進捗", isAssistant: true),
            line(threadId: "other", speaker: "codex", text: "別スレッドの進捗", isAssistant: true),
            line(threadId: "current", speaker: "tool", text: "現在スレッドの最新ツール", isAssistant: true)
        ]

        let planned = CodexConversationBubblePlanner.orderedThreadUpdates(
            from: lines,
            preferredThreadId: "other"
        )

        XCTAssertEqual(planned.map(\.threadId), ["other", "current"])
        XCTAssertEqual(planned.map(\.text), ["別スレッドの進捗", "現在スレッドの最新ツール"])
    }

    func testFallsBackToMostRecentThreadOrderWithoutPreferredThread() {
        let lines = [
            line(threadId: "a", speaker: "codex", text: "A1", isAssistant: true),
            line(threadId: "b", speaker: "codex", text: "B1", isAssistant: true),
            line(threadId: "a", speaker: "codex", text: "A2", isAssistant: true)
        ]

        let planned = CodexConversationBubblePlanner.orderedThreadUpdates(
            from: lines,
            preferredThreadId: nil
        )

        XCTAssertEqual(planned.map(\.threadId), ["a", "b"])
        XCTAssertEqual(planned.map(\.text), ["A2", "B1"])
    }

    func testConversationAnimationUsesNonWalkingMotionWhenIdle() {
        let assistant = line(threadId: "a", speaker: "codex", text: "完了", isAssistant: true)
        let user = line(threadId: "a", speaker: "you", text: "お願い", isAssistant: false)

        XCTAssertEqual(CodexConversationBubblePlanner.animation(for: assistant, fallback: .idle), .review)
        XCTAssertEqual(CodexConversationBubblePlanner.animation(for: user, fallback: .idle), .waving)
        XCTAssertEqual(CodexConversationBubblePlanner.animation(for: assistant, fallback: .running), .running)
    }

    func testSignatureSeparatesThreadSpeakerAndText() {
        let first = line(threadId: "a", speaker: "codex", text: "同じ本文", isAssistant: true)
        let second = line(threadId: "b", speaker: "codex", text: "同じ本文", isAssistant: true)

        XCTAssertNotEqual(
            CodexConversationBubblePlanner.signature(for: first),
            CodexConversationBubblePlanner.signature(for: second)
        )
    }

    func testPreferredThreadUpdateInsertsBeforeOtherPendingThreads() {
        let pending = [
            line(threadId: "other", speaker: "codex", text: "古い別スレッド", isAssistant: true),
            line(threadId: "third", speaker: "codex", text: "第三スレッド", isAssistant: true)
        ]
        let update = line(threadId: "current", speaker: "tool", text: "ツール: get_app_state", isAssistant: true)

        XCTAssertEqual(
            CodexConversationBubblePlanner.insertionIndex(
                for: update,
                preferredThreadId: "current",
                pendingLines: pending
            ),
            0
        )
    }

    func testNonPreferredThreadUpdateAppendsAfterPendingThreads() {
        let pending = [
            line(threadId: "current", speaker: "codex", text: "現在", isAssistant: true)
        ]
        let update = line(threadId: "other", speaker: "tool", text: "ツール: get_app_state", isAssistant: true)

        XCTAssertEqual(
            CodexConversationBubblePlanner.insertionIndex(
                for: update,
                preferredThreadId: "current",
                pendingLines: pending
            ),
            1
        )
    }

    private func line(
        threadId: String,
        speaker: String,
        text: String,
        isAssistant: Bool
    ) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: threadId,
            speaker: speaker,
            text: text,
            isAssistant: isAssistant
        )
    }
}
