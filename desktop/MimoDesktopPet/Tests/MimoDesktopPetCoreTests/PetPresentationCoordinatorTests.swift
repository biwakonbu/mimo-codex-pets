import XCTest
@testable import MimoDesktopPetCore

final class PetPresentationCoordinatorTests: XCTestCase {
    func testConnectedSnapshotStartsFocusedConversationBubbleAndThreadChips() {
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
        XCTAssertEqual(coordinator.presentation.bubbleText, "ご主人、「current」はコマンドを実行中です")
        XCTAssertEqual(coordinator.visibleBubbles.map(\.text), [
            "ご主人、「current」はコマンドを実行中です",
            "「waiting」確認待ち",
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
        XCTAssertEqual(coordinator.presentation.bubbleText, "ご主人、「current」は応答をまとめています")
        XCTAssertTrue(coordinator.hasActiveConversationBubble)

        let finished = coordinator.finishConversationBubble()

        XCTAssertFalse(finished.shouldScheduleConversationTimeout)
        XCTAssertEqual(coordinator.presentation, PetPresentationState(animation: .running, bubbleText: "Codex が作業中"))
        XCTAssertFalse(coordinator.hasPendingConversationBubbles)
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
            "ご主人、「current」は応答をまとめています"
        ])
    }

    func testAmbientMovementDoesNotInterruptActiveConversationBubble() {
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
        _ = coordinator.endAmbientMovement()

        XCTAssertEqual(coordinator.presentation.animation, .runningLeft)
        XCTAssertEqual(coordinator.presentation.bubbleText, "ご主人、「current」はコマンドを実行中です")
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
        activityKind: CodexConversationActivityKind = .message
    ) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: threadId,
            speaker: speaker,
            text: text,
            isAssistant: speaker != "you",
            activityKind: activityKind
        )
    }
}
