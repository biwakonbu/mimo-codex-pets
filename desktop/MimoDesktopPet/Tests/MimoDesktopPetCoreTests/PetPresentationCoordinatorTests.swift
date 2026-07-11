import XCTest
@testable import MimoDesktopPetCore

final class PetPresentationCoordinatorTests: XCTestCase {
    func testConnectedSnapshotStartsFocusedConversationBubbleAndThreadRows() {
        var coordinator = PetPresentationCoordinator()
        let current = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", activityKind: .command)
        let docs = line(threadId: "docs", speaker: "codex", text: "資料作業を進めています")
        let waiting = line(threadId: "waiting", speaker: "thread", text: "確認待ち", activityKind: .threadStatus)

        let change = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [current, docs, waiting],
            focusedConversationLine: current
        ))

        XCTAssertTrue(change.shouldScheduleConversationTimeout)
        XCTAssertEqual(coordinator.presentation.animation, .running)
        XCTAssertEqual(coordinator.presentation.bubbleText, "「current」はコマンドを実行中だよ")
        XCTAssertEqual(coordinator.visibleBubbles.map(\.text), [
            "「current」はコマンドを実行中だよ",
            "「waiting」返事待ちだよ",
            "「docs」進めてるよ"
        ])
        XCTAssertEqual(coordinator.visibleBubbles.map(\.role), [.focus, .conversation, .conversation])
        XCTAssertTrue(coordinator.hasActiveConversationBubble)
    }

    func testConversationTimeoutAdvancesQueueThenReturnsToCodexPresentation() {
        var coordinator = PetPresentationCoordinator()
        let first = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", activityKind: .command)
        let second = line(threadId: "current", speaker: "codex", text: "応答を作成中")
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [first, second],
            focusedConversationLine: first
        ))

        let next = coordinator.finishConversationBubble()

        XCTAssertTrue(next.shouldScheduleConversationTimeout)
        XCTAssertEqual(coordinator.presentation.bubbleText, "「current」は応答をまとめているよ")
        XCTAssertTrue(coordinator.hasActiveConversationBubble)

        let finished = coordinator.finishConversationBubble()

        XCTAssertFalse(finished.shouldScheduleConversationTimeout)
        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .running, bubbleText: CodexMimoStatusSpeech.active))
        XCTAssertFalse(coordinator.hasPendingConversationBubbles)
    }

    func testLongConversationBubblePagesBeforeAdvancingQueue() {
        var coordinator = PetPresentationCoordinator()
        let longSpeech = [
            "「Mimo runtime QA」で作業を進めているよ。",
            "Codex が吹き出しの幅と高さを広げて、長い説明も読みやすく整えています。",
            "Mimo は会話スキットとして区切りながら、必要なところまで順番に伝えます。",
            "収まりきらない時はページを送って、今なにをしているかを落ち着いて説明します。",
            "補助のチャット行も見える範囲に残して、状況を追いやすいようにします。"
        ].joined()
        let expectedPages = PetSpeechBubblePaginator.pages(
            for: longSpeech,
            role: .focus,
            limit: PetKataribeStageLayout.reportTextLimit
        )
        XCTAssertGreaterThan(expectedPages.count, 1)

        let first = line(
            threadId: "current",
            speaker: "codex",
            text: "応答を作成中",
            mimoSpeech: longSpeech
        )
        let second = line(threadId: "docs", speaker: "codex", text: "資料作業を進めています")
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [first, second],
            focusedConversationLine: first
        ))

        XCTAssertEqual(coordinator.presentation.bubbleText, expectedPages[0])
        XCTAssertEqual(coordinator.visibleBubbles.first?.text, expectedPages[0])
        XCTAssertEqual(
            coordinator.currentConversationMaximumPageTextLength,
            expectedPages.map { PetSpeechBubbleTextParts.parse($0).summary.count }.max() ?? 0
        )

        let secondPage = coordinator.finishConversationBubble()

        XCTAssertTrue(secondPage.shouldScheduleConversationTimeout)
        XCTAssertEqual(coordinator.presentation.bubbleText, expectedPages[1])
        XCTAssertEqual(coordinator.visibleBubbles.first?.text, expectedPages[1])
        XCTAssertTrue(coordinator.hasActiveConversationBubble)

        var next = secondPage
        for _ in 1..<expectedPages.count {
            next = coordinator.finishConversationBubble()
        }

        XCTAssertTrue(next.shouldScheduleConversationTimeout)
        XCTAssertEqual(coordinator.presentation.bubbleText, "「docs」は作業を進めているよ")
    }

    func testKataribeChatFeedAddsNarrationAtBottomAndOnlyPushesOlderChatsUp() {
        var coordinator = PetPresentationCoordinator()
        let first = line(threadId: "first", speaker: "codex", text: "最初の作業")
        let second = line(threadId: "second", speaker: "codex", text: "二番目の作業")
        let third = line(threadId: "third", speaker: "codex", text: "三番目の作業")

        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [first, second, third],
            focusedConversationLine: first
        ))

        XCTAssertEqual(coordinator.kataribeConversationLines.map(\.threadId), ["second", "third", "first"])
        XCTAssertEqual(coordinator.kataribeCharmRevisions["first"], 1)

        let updatedThird = line(threadId: "third", speaker: "codex", text: "三番目を更新")
        let updatedFirst = line(threadId: "first", speaker: "codex", text: "最初を更新")
        let updatedSecond = line(threadId: "second", speaker: "codex", text: "二番目を更新")
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [updatedThird, updatedFirst, updatedSecond],
            focusedConversationLine: updatedThird
        ))

        XCTAssertEqual(coordinator.kataribeConversationLines.map(\.threadId), ["second", "third", "first"])
        XCTAssertEqual(coordinator.kataribeConversationLines.map(\.text), ["二番目を更新", "三番目を更新", "最初を更新"])

        _ = coordinator.finishConversationBubble()

        XCTAssertEqual(coordinator.kataribeConversationLines.map(\.threadId), ["second", "first", "third"])
        XCTAssertEqual(coordinator.kataribeCharmRevisions["third"], 1)
    }

    func testKataribeChatRegistryRemovesChatsNoLongerInSnapshot() {
        var coordinator = PetPresentationCoordinator()
        let first = line(threadId: "first", speaker: "codex", text: "最初の作業")
        let second = line(threadId: "second", speaker: "codex", text: "二番目の作業")
        let third = line(threadId: "third", speaker: "codex", text: "三番目の作業")

        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [first, second, third]
        ))
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [first, third]
        ))

        XCTAssertEqual(coordinator.kataribeConversationLines.map(\.threadId), ["first", "third"])
    }

    func testActiveConversationBubbleImmediatelyAdoptsUrgentSecondaryState() {
        var coordinator = PetPresentationCoordinator()
        let current = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", activityKind: .command)
        let docs = line(threadId: "docs", speaker: "codex", text: "資料作業を進めています")
        let review = line(threadId: "review", speaker: "thread", text: "レビュー可能", activityKind: .review)
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [current, docs, review],
            focusedConversationLine: current
        ))
        let visibleDuringSpeech = coordinator.visibleBubbles

        let release = line(threadId: "release", speaker: "codex", text: "リリース準備を進めています")
        let waiting = line(threadId: "waiting", speaker: "thread", text: "確認待ち", activityKind: .threadStatus)
        let change = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [current, release, waiting],
            focusedConversationLine: current
        ))

        XCTAssertTrue(change.visibleBubblesChanged)
        XCTAssertEqual(coordinator.visibleBubbles.first?.text, visibleDuringSpeech.first?.text)
        XCTAssertEqual(coordinator.visibleBubbles.first?.threadId, "current")
        XCTAssertEqual(coordinator.visibleBubbles.first { $0.threadId == "waiting" }?.tone, .waiting)
        XCTAssertEqual(coordinator.conversationLines.map(\.threadId), ["current", "release", "waiting"])

        let tests = line(threadId: "tests", speaker: "tool", text: "テストを実行中", activityKind: .command)
        let overflowChange = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [current, release, waiting, tests, docs],
            focusedConversationLine: current
        ))

        XCTAssertTrue(overflowChange.visibleBubblesChanged)
        XCTAssertTrue(coordinator.visibleBubbles.contains { $0.role == .overflow })
        let firstOverflowText = coordinator.visibleBubbles.first { $0.role == .overflow }?.text

        let design = line(threadId: "design", speaker: "codex", text: "吹き出しを調整中")
        let largerOverflowChange = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [current, release, waiting, tests, docs, design],
            focusedConversationLine: current
        ))

        XCTAssertTrue(largerOverflowChange.visibleBubblesChanged)
        XCTAssertNotEqual(coordinator.visibleBubbles.first { $0.role == .overflow }?.text, firstOverflowText)
    }

    func testOfflineSnapshotClearsConversationStateAndUsesOfflineBubbleText() {
        var coordinator = PetPresentationCoordinator()
        let current = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", activityKind: .command)
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [current],
            focusedConversationLine: current
        ))

        let change = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: nil,
            latestTurnStatus: nil,
            hasRecentAssistantFinal: false,
            connectionAvailable: false,
            offlineBubbleText: CodexMimoStatusSpeech.disconnected
        ))

        XCTAssertFalse(change.shouldScheduleConversationTimeout)
        XCTAssertEqual(coordinator.presentation, PetPresentationState(
            animation: .idle,
            bubbleText: CodexMimoStatusSpeech.disconnected,
            isOffline: true
        ))
        XCTAssertEqual(coordinator.visibleBubbles.map(\.text), [CodexMimoStatusSpeech.disconnected])
        XCTAssertFalse(coordinator.hasPendingConversationBubbles)
        XCTAssertTrue(coordinator.conversationLines.isEmpty)
        XCTAssertTrue(coordinator.kataribeConversationLines.isEmpty)
    }

    func testDragPreservesConversationQueueAndRestoresCurrentConversation() {
        var coordinator = PetPresentationCoordinator()
        let current = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", activityKind: .command)
        let pending = line(threadId: "current", speaker: "codex", text: "応答を作成中")
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [current, pending],
            focusedConversationLine: current
        ))

        _ = coordinator.beginDrag(animation: .runningRight)

        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .runningRight, bubbleText: "「current」はコマンドを実行中だよ"))
        XCTAssertTrue(coordinator.hasPendingConversationBubbles)
        XCTAssertEqual(coordinator.visibleBubbles.map(\.text), [
            "「current」はコマンドを実行中だよ"
        ])

        _ = coordinator.endDrag()

        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .running, bubbleText: "「current」はコマンドを実行中だよ"))
        XCTAssertEqual(coordinator.visibleBubbles.map(\.text), [
            "「current」はコマンドを実行中だよ"
        ])

        _ = coordinator.finishConversationBubble()

        XCTAssertEqual(coordinator.presentation.bubbleText, "「current」は応答をまとめているよ")
    }

    func testAmbientMovementTemporarilyOverridesConversationAnimationAndRestoresIt() {
        var coordinator = PetPresentationCoordinator()
        let current = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", activityKind: .command)
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [current],
            focusedConversationLine: current
        ))

        _ = coordinator.beginAmbientMovement(animation: .runningLeft)

        XCTAssertEqual(coordinator.presentation.animation, .runningLeft)
        XCTAssertEqual(coordinator.presentation.bubbleText, "「current」はコマンドを実行中だよ")
        XCTAssertTrue(coordinator.hasActiveConversationBubble)

        _ = coordinator.endAmbientMovement()

        XCTAssertEqual(coordinator.presentation.animation, .running)
        XCTAssertEqual(coordinator.presentation.bubbleText, "「current」はコマンドを実行中だよ")
        XCTAssertTrue(coordinator.hasActiveConversationBubble)
    }

    func testTemporaryMomentRestoresLastCodexPresentation() {
        var coordinator = PetPresentationCoordinator()
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: [.waitingOnUserInput]),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true
        ))

        _ = coordinator.playMoment(animation: .waving, bubbleText: "呼びましたか?")

        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .waving, bubbleText: "呼びましたか?"))

        _ = coordinator.finishTemporaryPresentation()

        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .waiting, bubbleText: CodexMimoStatusSpeech.waiting))
    }

    func testTemporaryMomentPreservesConversationQueueAndCurrentSpeech() {
        var coordinator = PetPresentationCoordinator()
        let current = line(threadId: "current", speaker: "tool", text: "コマンドを実行中", activityKind: .command)
        let pending = line(threadId: "docs", speaker: "codex", text: "資料作業を進めています")
        _ = coordinator.apply(snapshot: PetCodexSnapshot(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false,
            connectionAvailable: true,
            conversationLines: [current, pending],
            focusedConversationLine: current
        ))
        let speechBeforeMoment = coordinator.presentation

        _ = coordinator.playMoment(animation: .waving, bubbleText: "呼びましたか?")
        XCTAssertTrue(coordinator.hasPendingConversationBubbles)

        _ = coordinator.finishTemporaryPresentation()
        XCTAssertEqual(coordinator.presentation, speechBeforeMoment)
        XCTAssertTrue(coordinator.hasPendingConversationBubbles)

        _ = coordinator.finishConversationBubble()
        XCTAssertEqual(coordinator.presentation.bubbleText, "「docs」は作業を進めているよ")
    }

    func testShowcaseSceneDirectlyControlsAnimationAndBubbleStack() {
        var coordinator = PetPresentationCoordinator()
        let scene = PetShowcaseScene(
            animation: .jumping,
            bubbleText: "「吹き出し演出」は確認してよさそう。あとで見てね",
            conversationLines: [
                line(threadId: "mimo-ui", speaker: "codex", text: "演出を調整中", activityKind: .fileChange),
                line(threadId: "release-dmg", speaker: "codex", text: "確認してよさそう", activityKind: .review)
            ],
            focusedThreadId: "mimo-ui",
            primaryThreadId: "mimo-ui",
            primaryActivityKind: .fileChange,
            duration: 3.0
        )

        let change = coordinator.apply(showcaseScene: scene)

        XCTAssertTrue(change.changed)
        XCTAssertFalse(change.shouldScheduleConversationTimeout)
        XCTAssertEqual(coordinator.presentation.animation, .jumping)
        XCTAssertEqual(coordinator.presentation.bubbleText, scene.bubbleText)
        XCTAssertEqual(coordinator.visibleBubbles.map(\.role), [.focus, .conversation])
        XCTAssertEqual(coordinator.visibleBubbles.first?.text, scene.bubbleText)
        XCTAssertFalse(coordinator.hasPendingConversationBubbles)
    }

    private func line(
        threadId: String,
        speaker: String,
        text: String,
        activityKind: CodexConversationActivityKind = .message,
        mimoSpeech: String? = nil
    ) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: threadId,
            speaker: speaker,
            text: text,
            isAssistant: speaker != "you",
            activityKind: activityKind,
            mimoSpeech: mimoSpeech
        )
    }
}
