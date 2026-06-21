import XCTest
@testable import MimoDesktopPetCore

final class CodexConversationLineCombinerTests: XCTestCase {
    func testCombinedLinesPreserveEveryTrackedThreadWhenCapped() {
        let ids = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta"]
        var conversationByThread: [String: [CodexConversationLine]] = [:]
        var activityByThread: [String: CodexConversationLine] = [:]

        for id in ids {
            conversationByThread[id] = [
                line(threadId: id, speaker: "you", text: "\(id) の依頼", isAssistant: false, activityKind: .userRequest),
                line(threadId: id, speaker: "tool", text: "\(id) のコマンドを実行中", activityKind: .command),
                line(threadId: id, speaker: "codex", text: "\(id) の応答を作成中", activityKind: .assistantMessage)
            ]
            activityByThread[id] = line(threadId: id, speaker: "thread", text: "作業中", activityKind: .threadStatus)
        }

        activityByThread["beta"] = line(threadId: "beta", speaker: "thread", text: "確認待ち", activityKind: .threadStatus)
        activityByThread["epsilon"] = line(threadId: "epsilon", speaker: "thread", text: "失敗を確認", activityKind: .threadStatus)

        let combined = CodexConversationLineCombiner.combinedConversationLines(
            threadDisplayOrder: ids,
            conversationByThread: conversationByThread,
            threadActivityById: activityByThread,
            preferredThreadId: "alpha",
            limit: 12
        )

        XCTAssertLessThanOrEqual(combined.count, 12)
        XCTAssertEqual(Set(combined.map(\.threadId)), Set(ids))
        XCTAssertTrue(combined.contains { $0.threadId == "beta" && $0.text == "確認待ち" })
        XCTAssertTrue(combined.contains { $0.threadId == "epsilon" && $0.text == "失敗を確認" })
        XCTAssertTrue(combined.contains { $0.threadId == "alpha" && $0.text == "alpha の応答を作成中" })
        XCTAssertTrue(combined.contains { $0.threadId == "zeta" && $0.text == "zeta の応答を作成中" })
    }

    func testCombinedLinesPreferFocusedThreadExtrasWhenCapped() {
        let ids = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta"]
        var conversationByThread: [String: [CodexConversationLine]] = [:]
        var activityByThread: [String: CodexConversationLine] = [:]

        for id in ids {
            conversationByThread[id] = [
                line(threadId: id, speaker: "tool", text: "\(id) ファイルを確認中", activityKind: .fileRead),
                line(threadId: id, speaker: "tool", text: "\(id) テストを実行中", activityKind: .test),
                line(threadId: id, speaker: "codex", text: "\(id) 計画を更新中", activityKind: .plan)
            ]
            activityByThread[id] = line(threadId: id, speaker: "thread", text: "作業中", activityKind: .threadStatus)
        }

        let combined = CodexConversationLineCombiner.combinedConversationLines(
            threadDisplayOrder: ids,
            conversationByThread: conversationByThread,
            threadActivityById: activityByThread,
            preferredThreadId: "alpha",
            limit: 8
        )

        XCTAssertEqual(combined.count, 8)
        XCTAssertEqual(Set(combined.map(\.threadId)), Set(ids))
        XCTAssertEqual(combined.filter { $0.threadId == "alpha" }.map(\.text), [
            "alpha ファイルを確認中",
            "alpha テストを実行中",
            "alpha 計画を更新中"
        ])
        XCTAssertEqual(combined.filter { $0.threadId != "alpha" }.count, 5)
    }

    func testOrderedLinesKeepActionRequiredActivityAsRepresentative() {
        let recent = [
            line(threadId: "waiting", speaker: "tool", text: "コマンドを実行中", activityKind: .command),
            line(threadId: "waiting", speaker: "codex", text: "応答を作成中", activityKind: .assistantMessage)
        ]
        let activity = line(threadId: "waiting", speaker: "thread", text: "確認待ち", activityKind: .threadStatus)

        let ordered = CodexConversationLineCombiner.orderedLines(
            recentLines: recent,
            activity: activity
        )

        XCTAssertEqual(ordered.map(\.text), ["コマンドを実行中", "応答を作成中", "確認待ち"])
    }

    func testOrderedLinesCarryRecentWorkSummaryIntoThreadActivity() {
        let recent = [
            line(
                threadId: "summary",
                speaker: "you",
                text: "吹き出しに作業内容の要約を出して",
                isAssistant: false,
                activityKind: .userRequest,
                workSummary: "作業内容の説明"
            ),
            line(
                threadId: "summary",
                speaker: "tool",
                text: "テストを実行中",
                activityKind: .test
            )
        ]
        let activity = line(threadId: "summary", speaker: "thread", text: "作業中", activityKind: .threadStatus)

        let ordered = CodexConversationLineCombiner.orderedLines(
            recentLines: recent,
            activity: activity
        )

        XCTAssertEqual(ordered.map(\.workSummary), [
            "作業内容の説明",
            "作業内容の説明",
            "作業内容の説明"
        ])
        let activityLine = ordered.first { $0.activityKind == .threadStatus }
        XCTAssertEqual(activityLine?.text, "作業中")
        XCTAssertEqual(
            CodexBubbleFormatter.bubbleText(for: activityLine!),
            "「summary」は作業内容の説明を進めているよ"
        )
    }

    func testOrderedLinesCarrySessionStateIntoRecentWorkLines() {
        let recent = [
            line(
                threadId: "summary",
                speaker: "you",
                text: "吹き出しに作業内容の要約を出して",
                isAssistant: false,
                activityKind: .userRequest,
                workSummary: "作業内容の説明"
            ),
            line(
                threadId: "summary",
                speaker: "tool",
                text: "テストを実行中",
                activityKind: .test
            )
        ]
        let activity = line(
            threadId: "summary",
            speaker: "thread",
            text: "作業中",
            activityKind: .threadStatus,
            sessionState: .active
        )

        let ordered = CodexConversationLineCombiner.orderedLines(
            recentLines: recent,
            activity: activity
        )

        XCTAssertEqual(ordered.map(\.sessionState), [.active, .active, .active])
        let testLine = ordered.first { $0.activityKind == .test }
        XCTAssertEqual(
            CodexBubbleFormatter.bubbleText(for: testLine!),
            "「summary」は作業内容の説明をテスト中だよ"
        )
    }

    private func line(
        threadId: String,
        speaker: String,
        text: String,
        isAssistant: Bool = true,
        activityKind: CodexConversationActivityKind,
        workSummary: String? = nil,
        sessionState: CodexSessionActivityState? = nil
    ) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: threadId,
            speaker: speaker,
            text: text,
            isAssistant: isAssistant,
            activityKind: activityKind,
            workSummary: workSummary,
            sessionState: sessionState
        )
    }
}
