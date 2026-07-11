import XCTest
@testable import MimoDesktopPetCore

final class CodexConversationVisibilityPolicyTests: XCTestCase {
    func testActiveThreadIsVisibleWithoutRecentActivityTimestamp() {
        XCTAssertTrue(
            CodexConversationVisibilityPolicy.shouldShow(
                threadStatus: .active(activeFlags: []),
                latestTurnStatus: nil,
                lastActivityAge: nil
            )
        )
    }

    func testInProgressTurnIsVisibleEvenWhenThreadStatusIsMissing() {
        XCTAssertTrue(
            CodexConversationVisibilityPolicy.shouldShow(
                threadStatus: nil,
                latestTurnStatus: .inProgress,
                lastActivityAge: nil
            )
        )
    }

    func testRecentlyStoppedThreadRemainsVisible() {
        XCTAssertTrue(
            CodexConversationVisibilityPolicy.shouldShow(
                threadStatus: .idle,
                latestTurnStatus: .completed,
                lastActivityAge: 179
            )
        )
    }

    func testOldStoppedThreadIsHidden() {
        XCTAssertFalse(
            CodexConversationVisibilityPolicy.shouldShow(
                threadStatus: .idle,
                latestTurnStatus: .completed,
                lastActivityAge: 181
            )
        )
    }

    func testNeverObservedStoppedThreadIsHidden() {
        XCTAssertFalse(
            CodexConversationVisibilityPolicy.shouldShow(
                threadStatus: .idle,
                latestTurnStatus: .completed,
                lastActivityAge: nil
            )
        )
    }
}
