import XCTest
@testable import MimoDesktopPetCore

final class StateMappingTests: XCTestCase {
    func testActiveMapsToRunning() {
        let state = CodexPetStateMapper.presentation(
            threadStatus: .active(activeFlags: []),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false
        )

        XCTAssertEqual(state.animation, .running)
        XCTAssertEqual(state.bubbleText, CodexMimoStatusSpeech.active)
    }

    func testWaitingFlagsMapToWaiting() {
        let approval = CodexPetStateMapper.presentation(
            threadStatus: .active(activeFlags: [.waitingOnApproval]),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false
        )
        let input = CodexPetStateMapper.presentation(
            threadStatus: .active(activeFlags: [.waitingOnUserInput]),
            latestTurnStatus: .inProgress,
            hasRecentAssistantFinal: false
        )

        XCTAssertEqual(approval.animation, .waiting)
        XCTAssertEqual(input.animation, .waiting)
        XCTAssertEqual(approval.bubbleText, CodexMimoStatusSpeech.waiting)
        XCTAssertEqual(input.bubbleText, CodexMimoStatusSpeech.waiting)
    }

    func testFailedTurnAndSystemErrorMapToFailed() {
        let failedTurn = CodexPetStateMapper.presentation(
            threadStatus: .idle,
            latestTurnStatus: .failed,
            hasRecentAssistantFinal: false
        )
        let systemError = CodexPetStateMapper.presentation(
            threadStatus: .systemError,
            latestTurnStatus: .completed,
            hasRecentAssistantFinal: true
        )

        XCTAssertEqual(failedTurn.animation, .failed)
        XCTAssertEqual(systemError.animation, .failed)
        XCTAssertEqual(failedTurn.bubbleText, CodexMimoStatusSpeech.failed)
        XCTAssertEqual(systemError.bubbleText, CodexMimoStatusSpeech.systemError)
    }

    func testCompletedAssistantFinalMapsToReview() {
        let state = CodexPetStateMapper.presentation(
            threadStatus: .idle,
            latestTurnStatus: .completed,
            hasRecentAssistantFinal: true
        )

        XCTAssertEqual(state.animation, .review)
        XCTAssertEqual(state.bubbleText, CodexMimoStatusSpeech.review)
    }

    func testMissingConnectionMapsToOfflineIdle() {
        let state = CodexPetStateMapper.presentation(
            threadStatus: nil,
            latestTurnStatus: nil,
            hasRecentAssistantFinal: false,
            connectionAvailable: false
        )

        XCTAssertEqual(state.animation, .idle)
        XCTAssertEqual(state.bubbleText, CodexMimoStatusSpeech.connecting)
        XCTAssertTrue(state.isOffline)
    }

    func testDragDirectionMapsToDirectionalRows() {
        XCTAssertEqual(CodexPetStateMapper.dragPresentation(deltaX: 12).animation, .runningRight)
        XCTAssertEqual(CodexPetStateMapper.dragPresentation(deltaX: -12).animation, .runningLeft)
        XCTAssertEqual(CodexPetStateMapper.dragPresentation(deltaX: 12).bubbleText, CodexMimoStatusSpeech.moving)
    }
}
