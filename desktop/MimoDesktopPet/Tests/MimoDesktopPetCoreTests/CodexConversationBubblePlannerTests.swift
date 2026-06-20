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

    func testPreferredThreadKeepsStreamingProgressBeforeLatestLine() {
        let lines = [
            line(threadId: "current", speaker: "tool", text: "ツールで確認中", isAssistant: true),
            line(threadId: "current", speaker: "codex", text: "応答を作成中", isAssistant: true),
            line(threadId: "current", speaker: "codex", text: "計画を更新中", isAssistant: true),
            line(threadId: "current", speaker: "tool", text: "コマンド出力を確認中", isAssistant: true),
            line(threadId: "current", speaker: "codex", text: "最後の通常報告", isAssistant: true),
            line(threadId: "other", speaker: "codex", text: "別スレッド", isAssistant: true)
        ]

        let planned = CodexConversationBubblePlanner.orderedThreadUpdates(
            from: lines,
            preferredThreadId: "current"
        )

        XCTAssertEqual(planned.map(\.text), [
            "ツールで確認中",
            "応答を作成中",
            "計画を更新中",
            "コマンド出力を確認中",
            "最後の通常報告",
            "別スレッド"
        ])
    }

    func testOrderedThreadUpdatesDeduplicateEquivalentMimoReports() {
        let lines = [
            line(threadId: "current", speaker: "tool", text: "コマンド出力を確認中", isAssistant: true),
            line(threadId: "current", speaker: "tool", text: "コマンドを実行中", isAssistant: true),
            line(threadId: "current", speaker: "codex", text: "応答を作成中", isAssistant: true),
            line(threadId: "other", speaker: "tool", text: "コマンドを実行中", isAssistant: true)
        ]

        let planned = CodexConversationBubblePlanner.orderedThreadUpdates(
            from: lines,
            preferredThreadId: "current"
        )

        XCTAssertEqual(planned.map(\.text), [
            "コマンド出力を確認中",
            "応答を作成中",
            "コマンドを実行中"
        ])
    }

    func testOrderedThreadUpdatesPrioritizeActionRequiredStatuses() {
        let lines = [
            line(threadId: "active", speaker: "thread", text: "作業中", isAssistant: true),
            line(threadId: "review", speaker: "thread", text: "レビュー可能", isAssistant: true),
            line(threadId: "waiting", speaker: "thread", text: "確認待ち", isAssistant: true),
            line(threadId: "failed", speaker: "thread", text: "失敗を確認", isAssistant: true)
        ]

        let planned = CodexConversationBubblePlanner.orderedThreadUpdates(
            from: lines,
            preferredThreadId: "active"
        )

        XCTAssertEqual(planned.map(\.threadId), ["failed", "waiting", "review", "active"])
        XCTAssertEqual(planned.map(CodexConversationBubblePlanner.displayPriority(for:)), [0, 1, 2, 3])
    }

    func testProductionBubblesIncludeMultipleThreadSummaries() {
        let lines = [
            line(threadId: "current", speaker: "tool", text: "ツールで確認中", isAssistant: true),
            line(threadId: "other", speaker: "codex", text: "レビューできる状態になりました", isAssistant: true),
            line(threadId: "third", speaker: "codex", text: "移動先を調整しています", isAssistant: true)
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: "Codex が作業中",
            conversationLines: lines,
            preferredThreadId: "current",
            limit: 4
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "Codex が作業中",
            "「other」レビュー可",
            "「current」ツール確認",
            "「third」作業中"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.status, .conversation, .conversation, .conversation])
    }

    func testProductionBubblesRespectProductStackTextLimits() {
        let lines = [
            line(
                threadId: String(repeating: "長いタイトル", count: 8),
                speaker: "codex",
                text: "デスクトップ上の表示座標を確認しながら移動先を調整しています",
                isAssistant: true
            ),
            line(
                threadId: String(repeating: "別スレッド", count: 8),
                speaker: "tool",
                text: "実行: swift test --very-long-option --another-long-option",
                isAssistant: true
            )
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: String(repeating: "本番ステータス", count: 8),
            conversationLines: lines,
            preferredThreadId: nil,
            limit: 9
        )

        XCTAssertLessThanOrEqual(bubbles.count, PetSpeechBubbleLayout.productionVisibleLimit)
        XCTAssertEqual(bubbles.first?.role, .status)
        XCTAssertLessThanOrEqual(bubbles[0].text.count, PetSpeechBubbleLayout.statusTextLimit)
        for bubble in bubbles.dropFirst() {
            XCTAssertTrue([PetSpeechBubbleRole.conversation, .overflow].contains(bubble.role))
            XCTAssertLessThanOrEqual(bubble.text.count, PetSpeechBubbleLayout.textLimit(for: bubble.role))
        }
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .status), 2)
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .conversation), 1)
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .overflow), 1)
    }

    func testProductionBubblesUseOneSummaryPerThread() {
        let lines = [
            line(threadId: "current", speaker: "tool", text: "ツールで確認中", isAssistant: true),
            line(threadId: "current", speaker: "codex", text: "応答を作成中", isAssistant: true),
            line(threadId: "current", speaker: "codex", text: "計画を更新中", isAssistant: true),
            line(threadId: "other", speaker: "codex", text: "レビューできる状態になりました", isAssistant: true),
            line(threadId: "third", speaker: "codex", text: "資料作業を進めています", isAssistant: true)
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: "Codex が作業中",
            conversationLines: lines,
            preferredThreadId: "current",
            limit: 4
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "Codex が作業中",
            "「other」レビュー可",
            "「current」ツール確認",
            "「third」作業中"
        ])
    }

    func testProductionBubblesReserveLastConversationBubbleForOverflow() {
        let lines = [
            line(threadId: "alpha", speaker: "codex", text: "作業を進めています", isAssistant: true),
            line(threadId: "beta", speaker: "codex", text: "作業を進めています", isAssistant: true),
            line(threadId: "gamma", speaker: "codex", text: "作業を進めています", isAssistant: true),
            line(threadId: "delta", speaker: "codex", text: "作業を進めています", isAssistant: true),
            line(threadId: "epsilon", speaker: "codex", text: "作業を進めています", isAssistant: true)
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: "Codex が作業中",
            conversationLines: lines,
            preferredThreadId: nil,
            limit: 4
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "Codex が作業中",
            "「epsilon」作業中",
            "「delta」作業中",
            "ほか3件も見ています"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.status, .conversation, .conversation, .overflow])
        XCTAssertLessThanOrEqual(bubbles[3].text.count, PetSpeechBubbleLayout.overflowTextLimit)
    }

    func testProductionBubblesKeepAConcreteThreadWhenOnlyOneContextSlotIsAvailable() {
        let lines = [
            line(threadId: "alpha", speaker: "codex", text: "作業を進めています", isAssistant: true),
            line(threadId: "beta", speaker: "codex", text: "作業を進めています", isAssistant: true)
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: "Codex が作業中",
            conversationLines: lines,
            preferredThreadId: nil,
            limit: 2
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "Codex が作業中",
            "「beta」作業中"
        ])
    }

    func testProductionBubblesSkipPrimaryThreadWhenConversationBubbleIsCurrent() {
        let current = line(threadId: "current", speaker: "codex", text: "応答を作成中", isAssistant: true)
        let lines = [
            line(threadId: "other", speaker: "codex", text: "レビューできる状態になりました", isAssistant: true),
            line(threadId: "third", speaker: "codex", text: "資料作業を進めています", isAssistant: true),
            line(threadId: "fourth", speaker: "thread", text: "確認待ち", isAssistant: true),
            current
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: CodexBubbleFormatter.bubbleText(for: current),
            conversationLines: lines,
            preferredThreadId: "current",
            primaryThreadId: "current",
            limit: 4
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "ご主人、「current」は応答をまとめています",
            "「fourth」確認待ち",
            "「other」レビュー可",
            "「third」作業中"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation, .conversation])
    }

    func testProductionBubblesDeduplicatePrimaryConversationText() {
        let current = line(threadId: "current", speaker: "codex", text: "応答を作成中", isAssistant: true)
        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: CodexBubbleFormatter.bubbleText(for: current),
            conversationLines: [current],
            preferredThreadId: "current",
            primaryThreadId: "current",
            limit: 3
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "ご主人、「current」は応答をまとめています"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.focus])
    }

    func testPrimaryBubblePromotesFocusedThreadSummaryAndSkipsDuplicateThread() {
        let current = line(threadId: "current", speaker: "codex", text: "実行に失敗しました。確認が必要です", isAssistant: true)
        let lines = [
            current,
            line(threadId: "docs", speaker: "codex", text: "資料作業を進めています", isAssistant: true),
            line(threadId: "waiting", speaker: "thread", text: "確認待ち", isAssistant: true)
        ]

        let primary = CodexConversationBubblePlanner.primaryBubble(
            statusText: "実行に失敗しました",
            conversationLines: lines,
            preferredThreadId: "current"
        )
        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: primary.text,
            conversationLines: lines,
            preferredThreadId: "current",
            primaryThreadId: primary.threadId,
            limit: 4
        )

        XCTAssertEqual(primary.threadId, "current")
        XCTAssertEqual(bubbles.map(\.text), [
            "ご主人、「current」は失敗を確認しました",
            "「waiting」確認待ち",
            "「docs」作業中"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation])
    }

    func testFocusedPrimaryThreadUsesFocusRoleAndKeepsOverflowForExtraThreads() {
        let current = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", isAssistant: true)
        let lines = [
            current,
            line(threadId: "waiting", speaker: "thread", text: "確認待ち", isAssistant: true),
            line(threadId: "review", speaker: "thread", text: "レビュー可能", isAssistant: true),
            line(threadId: "docs", speaker: "codex", text: "資料作業を進めています", isAssistant: true),
            line(threadId: "tests", speaker: "tool", text: "テストを実行中", isAssistant: true)
        ]
        let primary = CodexConversationBubblePlanner.primaryBubble(
            statusText: "Codex が作業中",
            conversationLines: lines,
            preferredThreadId: "current"
        )

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: primary.text,
            conversationLines: lines,
            preferredThreadId: "current",
            primaryThreadId: primary.threadId,
            limit: 4
        )

        XCTAssertEqual(primary.threadId, "current")
        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation, .overflow])
        XCTAssertEqual(bubbles.first?.text, "ご主人、「current」はコマンドを実行中です")
        XCTAssertEqual(bubbles.last?.text, "ほか2件も見ています")
    }

    func testPrimaryBubbleKeepsOfflineStatusText() {
        let primary = CodexConversationBubblePlanner.primaryBubble(
            statusText: "Codex 接続待ち",
            conversationLines: [
                line(threadId: "current", speaker: "codex", text: "作業を進めています", isAssistant: true)
            ],
            preferredThreadId: "current",
            isOffline: true
        )

        XCTAssertEqual(primary, CodexConversationBubblePlanner.PrimaryBubble(text: "Codex 接続待ち", threadId: nil))
    }

    func testProductionBubblesFallbackToIdleWhenEmpty() {
        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: "",
            conversationLines: [],
            preferredThreadId: nil
        )

        XCTAssertEqual(bubbles.map(\.text), ["待機中"])
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

    func testDisplaySignatureDeduplicatesDifferentRawLinesWithSameMimoReport() {
        let first = line(threadId: "a", speaker: "tool", text: "コマンド出力を確認中", isAssistant: true)
        let second = line(threadId: "a", speaker: "tool", text: "コマンドを実行中", isAssistant: true)

        XCTAssertNotEqual(
            CodexConversationBubblePlanner.signature(for: first),
            CodexConversationBubblePlanner.signature(for: second)
        )
        XCTAssertEqual(
            CodexConversationBubblePlanner.displaySignature(for: first),
            CodexConversationBubblePlanner.displaySignature(for: second)
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
