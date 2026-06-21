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
            "「other」ひと段落",
            "「current」ツール確認",
            "「third」Mimo の動き中"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.status, .conversation, .conversation, .conversation])
    }

    func testProductionBubblesUseMimoReportOnlyForPrimaryAndThreadRowsForSecondaryBubbles() {
        let current = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", isAssistant: true)
        let lines = [
            current,
            line(threadId: "docs", speaker: "codex", text: "資料作業を進めています", isAssistant: true),
            line(threadId: "waiting", speaker: "thread", text: "確認待ち", isAssistant: true),
            line(threadId: "review", speaker: "thread", text: "レビュー可能", isAssistant: true)
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: CodexBubbleFormatter.bubbleText(for: current),
            conversationLines: lines,
            preferredThreadId: "current",
            primaryThreadId: "current",
            primaryActivityKind: current.activityKind,
            limit: 4
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "「current」はコマンドを実行中だよ",
            "「waiting」返事待ち",
            "「review」ひと段落",
            "「docs」作業中"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation, .conversation])
        XCTAssertTrue(bubbles[0].text.hasPrefix("「current」"))
        XCTAssertTrue(bubbles.allSatisfy { !$0.text.contains("ご主人") })
        XCTAssertTrue(bubbles.dropFirst().allSatisfy { $0.text.hasPrefix("「") })
    }

    func testProductionBubblesCarrySemanticTonesForThreadState() {
        let lines = [
            line(threadId: "failed", speaker: "codex", text: "実行に失敗しました。確認が必要です", isAssistant: true),
            line(threadId: "waiting", speaker: "thread", text: "確認待ち", isAssistant: true),
            line(threadId: "review", speaker: "codex", text: "レビューできる状態になりました", isAssistant: true)
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: "Codex が作業中",
            conversationLines: lines,
            preferredThreadId: nil,
            limit: 4
        )

        XCTAssertEqual(bubbles.map(\.role), [.status, .conversation, .conversation, .conversation])
        XCTAssertEqual(bubbles.map(\.tone), [.active, .failed, .waiting, .review])
    }

    func testProductionBubblesCarryActivityKindsForVisualMarkers() {
        let current = line(
            threadId: "current",
            speaker: "tool",
            text: "テストを実行中",
            isAssistant: true,
            activityKind: .test
        )
        let lines = [
            current,
            line(
                threadId: "image",
                speaker: "tool",
                text: "画像を生成中",
                isAssistant: true,
                activityKind: .imageGeneration
            ),
            line(
                threadId: "browser",
                speaker: "tool",
                text: "ページを確認中",
                isAssistant: true,
                activityKind: .browser
            ),
            line(
                threadId: "plan",
                speaker: "codex",
                text: "計画を更新中",
                isAssistant: true,
                activityKind: .plan
            ),
            line(
                threadId: "files",
                speaker: "tool",
                text: "ファイルを確認中",
                isAssistant: true,
                activityKind: .fileRead
            )
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
            primaryActivityKind: primary.activityKind,
            limit: 4
        )

        XCTAssertEqual(primary.activityKind, .test)
        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation, .overflow])
        XCTAssertEqual(bubbles.map(\.activityKind), [.test, .fileRead, .plan, nil])
        XCTAssertTrue(bubbles[0].id.contains("test"))
        XCTAssertTrue(bubbles[1].id.contains("fileRead"))
        XCTAssertTrue(bubbles[2].id.contains("plan"))
    }

    func testProductionBubblesUseOverflowToneWhenMoreThreadsAreHidden() {
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

        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation, .overflow])
        XCTAssertEqual(bubbles.map(\.tone), [.waiting, .review, .active, .overflow])
    }

    func testOverflowBubblePreservesHiddenWaitingUrgency() {
        let lines = [
            line(threadId: "waiting-1", speaker: "thread", text: "確認待ち", isAssistant: true),
            line(threadId: "waiting-2", speaker: "thread", text: "確認待ち", isAssistant: true),
            line(threadId: "waiting-3", speaker: "thread", text: "確認待ち", isAssistant: true),
            line(threadId: "waiting-4", speaker: "thread", text: "確認待ち", isAssistant: true),
            line(threadId: "waiting-5", speaker: "thread", text: "確認待ち", isAssistant: true)
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: "Codex が作業中",
            conversationLines: lines,
            preferredThreadId: nil,
            limit: 4
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "Codex が作業中",
            "「waiting-5」返事待ち",
            "「waiting-4」返事待ち",
            "ほか3件に確認待ち"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.status, .conversation, .conversation, .overflow])
        XCTAssertEqual(bubbles.map(\.tone), [.active, .waiting, .waiting, .waiting])
    }

    func testOverflowBubblePreservesHiddenFailureUrgency() {
        let lines = [
            line(threadId: "failed-1", speaker: "codex", text: "実行に失敗しました", isAssistant: true),
            line(threadId: "failed-2", speaker: "codex", text: "systemError を確認", isAssistant: true),
            line(threadId: "failed-3", speaker: "codex", text: "エラーを確認", isAssistant: true),
            line(threadId: "failed-4", speaker: "codex", text: "failed", isAssistant: true),
            line(threadId: "active", speaker: "codex", text: "作業を進めています", isAssistant: true)
        ]

        let bubbles = CodexConversationBubblePlanner.productionBubbles(
            primaryText: "Codex が作業中",
            conversationLines: lines,
            preferredThreadId: nil,
            limit: 4
        )

        XCTAssertEqual(bubbles.map(\.text), [
            "Codex が作業中",
            "「failed-4」つまずきあり",
            "「failed-3」つまずきあり",
            "ほか3件に失敗あり"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.status, .conversation, .conversation, .overflow])
        XCTAssertEqual(bubbles.map(\.tone), [.active, .failed, .failed, .failed])
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
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .status), 4)
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .conversation), 2)
        XCTAssertEqual(PetSpeechBubbleLayout.lineLimit(for: .overflow), 1)
        XCTAssertEqual(PetSpeechBubbleLayout.textLimit(for: .conversation), 96)
        XCTAssertEqual(PetSpeechBubbleLayout.titleLineLimit(for: .conversation), 2)
        XCTAssertEqual(PetSpeechBubbleLayout.summaryLineLimit(for: .conversation), 1)
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
            "「other」ひと段落",
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

    func testProductionDefaultStackShowsThreeConcreteThreadsBeforeOverflow() {
        let focused = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", isAssistant: true)
        let lines = [
            focused,
            line(threadId: "waiting", speaker: "thread", text: "確認待ち", isAssistant: true),
            line(threadId: "review", speaker: "thread", text: "レビュー可能", isAssistant: true),
            line(threadId: "docs", speaker: "codex", text: "資料作業を進めています", isAssistant: true),
            line(threadId: "tests", speaker: "tool", text: "テストを実行中", isAssistant: true),
            line(threadId: "release", speaker: "codex", text: "リリース準備を進めています", isAssistant: true)
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
            primaryThreadId: primary.threadId
        )

        XCTAssertEqual(bubbles.count, PetSpeechBubbleLayout.productionVisibleLimit)
        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation, .conversation, .overflow])
        XCTAssertEqual(bubbles.map(\.text), [
            "「waiting」は確認を待っているよ",
            "「review」ひと段落",
            "「current」実行中",
            "「release」進捗あり",
            "ほか2件も見ています"
        ])
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
            "「current」は応答をまとめているよ",
            "「fourth」返事待ち",
            "「other」ひと段落",
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
            "「current」は応答をまとめているよ"
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
            "「current」はつまずいたところを見つけたよ",
            "「waiting」返事待ち",
            "「docs」作業中"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation])
    }

    func testPrimaryBubblePromotesActionRequiredThreadAheadOfActivePreferredThread() {
        let current = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", isAssistant: true)
        let lines = [
            current,
            line(threadId: "docs", speaker: "codex", text: "資料作業を進めています", isAssistant: true),
            line(threadId: "waiting", speaker: "thread", text: "確認待ち", isAssistant: true)
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

        XCTAssertEqual(primary.threadId, "waiting")
        XCTAssertEqual(primary.activityKind, .message)
        XCTAssertEqual(bubbles.map(\.text), [
            "「waiting」は確認を待っているよ",
            "「current」実行中",
            "「docs」作業中"
        ])
        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation])
        XCTAssertEqual(bubbles.map(\.tone), [.waiting, .active, .active])
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

        XCTAssertEqual(primary.threadId, "waiting")
        XCTAssertEqual(bubbles.map(\.role), [.focus, .conversation, .conversation, .overflow])
        XCTAssertEqual(bubbles.first?.text, "「waiting」は確認を待っているよ")
        XCTAssertEqual(bubbles.dropFirst().map(\.text), [
            "「review」ひと段落",
            "「current」実行中",
            "ほか2件も見ています"
        ])
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
        isAssistant: Bool,
        activityKind: CodexConversationActivityKind = .message
    ) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: threadId,
            speaker: speaker,
            text: text,
            isAssistant: isAssistant,
            activityKind: activityKind
        )
    }
}
