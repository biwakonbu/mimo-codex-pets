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
            "「waiting」返事待ち",
            "「docs」作業中"
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
        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .running, bubbleText: "Codex が作業中"))
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
        let expectedPages = PetSpeechBubblePaginator.pages(for: longSpeech, role: .focus)
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
            offlineBubbleText: "Codex 接続切れ"
        ))

        XCTAssertFalse(change.shouldScheduleConversationTimeout)
        XCTAssertEqual(coordinator.presentation, PetPresentationState(
            animation: .idle,
            bubbleText: "Codex 接続切れ",
            isOffline: true
        ))
        XCTAssertEqual(coordinator.visibleBubbles.map(\.text), ["Codex 接続切れ"])
        XCTAssertFalse(coordinator.hasPendingConversationBubbles)
        XCTAssertTrue(coordinator.conversationLines.isEmpty)
    }

    func testDragClearsConversationQueueAndRestoresLastCodexPresentation() {
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

        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .runningRight, bubbleText: "移動中"))
        XCTAssertFalse(coordinator.hasPendingConversationBubbles)

        _ = coordinator.endDrag()

        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .running, bubbleText: "Codex が作業中"))
        XCTAssertEqual(coordinator.visibleBubbles.map(\.text), [
            "「current」は応答をまとめているよ"
        ])
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

        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .waiting, bubbleText: "確認を待っています"))
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
