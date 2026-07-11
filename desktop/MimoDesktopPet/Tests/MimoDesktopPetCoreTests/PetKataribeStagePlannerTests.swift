import XCTest
@testable import MimoDesktopPetCore

final class PetKataribeStagePlannerTests: XCTestCase {
    func testOneThreeAndSixChatsRemainNamedWithoutOverflow() {
        for count in [1, 3, 6] {
            let lines = (0..<count).map { index in
                line(threadId: "thread-\(index)", title: "チャット \(index + 1)")
            }
            let report = bubble(for: lines[0])

            let stage = PetKataribeStagePlanner.presentation(
                visibleBubbles: [report],
                conversationLines: lines
            )

            XCTAssertEqual(stage.charms.count, count)
            XCTAssertEqual(stage.charms.map(\.title), lines.map(\.threadTitle))
            XCTAssertFalse(stage.charms.contains { $0.title.contains("ほか") })
            XCTAssertEqual(stage.charms.filter(\.isSelected).map(\.threadId), ["thread-0"])
        }
    }

    func testPlannerPreservesCoordinatorFeedOrderWhenNarratorChanges() {
        let lines = [
            line(threadId: "first", title: "請求書リニューアル"),
            line(threadId: "second", title: "ログイン改修"),
            line(threadId: "third", title: "検索の高速化")
        ]
        let firstStage = PetKataribeStagePlanner.presentation(
            visibleBubbles: [bubble(for: lines[0])],
            conversationLines: lines
        )
        let secondStage = PetKataribeStagePlanner.presentation(
            visibleBubbles: [bubble(for: lines[1])],
            conversationLines: lines
        )

        XCTAssertEqual(firstStage.charms.map(\.threadId), secondStage.charms.map(\.threadId))
        XCTAssertEqual(secondStage.charms.first(where: \.isSelected)?.threadId, "second")
    }

    func testNarrationRevisionCreatesANewBottomFeedBubbleIdentity() {
        let lines = [
            line(threadId: "older", title: "前のチャット"),
            line(threadId: "current", title: "いまのチャット")
        ]
        let before = PetKataribeStagePlanner.presentation(
            visibleBubbles: [bubble(for: lines[1])],
            conversationLines: lines,
            charmRevisions: ["current": 2]
        )
        let after = PetKataribeStagePlanner.presentation(
            visibleBubbles: [bubble(for: lines[1])],
            conversationLines: lines,
            charmRevisions: ["current": 3]
        )

        XCTAssertEqual(before.charms.map(\.threadId), ["older", "current"])
        XCTAssertNotEqual(before.charms.last?.id, after.charms.last?.id)
        XCTAssertTrue(after.charms.last?.id.hasSuffix(":3") == true)
    }

    func testNarratedChatStaysAtFeedBottomWhenMoreThanSixChatsAreKnown() {
        let lines = (0..<7).map { index in
            line(threadId: "thread-\(index)", title: "チャット \(index + 1)")
        }
        let stage = PetKataribeStagePlanner.presentation(
            visibleBubbles: [bubble(for: lines[6])],
            conversationLines: lines,
            charmRevisions: ["thread-6": 4]
        )

        XCTAssertEqual(stage.charms.count, 6)
        XCTAssertEqual(stage.charms.last?.threadId, "thread-6")
        XCTAssertTrue(stage.charms.last?.isSelected == true)
    }

    func testUrgentChatCanInterruptNarrationWithoutRawStatusChrome() {
        let active = line(threadId: "active", title: "検索の高速化")
        let waiting = line(
            threadId: "waiting",
            title: "ログイン改修",
            text: "確認待ち",
            activityKind: .threadStatus
        )
        let stage = PetKataribeStagePlanner.presentation(
            visibleBubbles: [
                bubble(for: active),
                PetSpeechBubble(
                    id: "thread:waiting",
                    text: "「ログイン改修」は再設定メールの文面を確認してほしいみたい",
                    role: .conversation,
                    tone: .waiting,
                    activityKind: .threadStatus,
                    threadId: "waiting",
                    threadTitle: "ログイン改修"
                )
            ],
            conversationLines: [active, waiting],
            pageNumber: 2,
            pageCount: 3
        )

        XCTAssertEqual(stage.report.threadId, "waiting")
        XCTAssertEqual(stage.pageNumber, 1)
        XCTAssertEqual(stage.pageCount, 1)
        XCTAssertEqual(stage.charms.first(where: \.isSelected)?.threadId, "waiting")
    }

    func testNarrationAndEveryCharmOpenTheirExactChat() {
        let lines = (0..<6).map { index in
            line(threadId: "thread-\(index)", title: "チャット \(index + 1)")
        }
        let stage = PetKataribeStagePlanner.presentation(
            visibleBubbles: [bubble(for: lines[2])],
            conversationLines: lines,
            pageNumber: 2,
            pageCount: 2
        )

        XCTAssertEqual(stage.pageNumber, 2)
        XCTAssertEqual(stage.pageCount, 2)
        XCTAssertEqual(stage.interactiveBubbles.count, 7)
        XCTAssertEqual(Set(stage.interactiveBubbles.compactMap(\.threadId)), Set(lines.map(\.threadId)))
    }

    func testReportHeightUsesLongestPageInsteadOfJumpingBetweenPages() {
        let current = line(threadId: "current", title: "長い報告")
        let firstPage = PetKataribeStagePlanner.presentation(
            visibleBubbles: [bubble(for: current)],
            conversationLines: [current],
            pageNumber: 1,
            pageCount: 2,
            maximumPageTextLength: 96
        )
        let shortSecondPage = PetSpeechBubble(
            id: "thread:current",
            text: "つづきだよ",
            role: .focus,
            tone: .active,
            threadId: "current",
            threadTitle: "長い報告"
        )
        let secondPage = PetKataribeStagePlanner.presentation(
            visibleBubbles: [shortSecondPage],
            conversationLines: [current],
            pageNumber: 2,
            pageCount: 2,
            maximumPageTextLength: 96
        )

        XCTAssertEqual(firstPage.reportLayoutTextLength, 96)
        XCTAssertEqual(secondPage.reportLayoutTextLength, 96)
        XCTAssertEqual(
            PetKataribeStageLayout.reportFrame(forTextLength: firstPage.reportLayoutTextLength),
            PetKataribeStageLayout.reportFrame(forTextLength: secondPage.reportLayoutTextLength)
        )
    }

    func testCompactPaginationUsesOnlyTwoTightReportHeights() {
        let compact = PetKataribeStageLayout.reportFrame(
            forTextLength: PetKataribeStageLayout.compactReportTextLimit
        )
        let expanded = PetKataribeStageLayout.reportFrame(
            forTextLength: PetKataribeStageLayout.compactReportTextLimit + 1
        )

        XCTAssertEqual(PetKataribeStageLayout.reportTextLimit, 64)
        XCTAssertEqual(compact.height, 128)
        XCTAssertEqual(expanded.height, 184)
        XCTAssertEqual(PetKataribeStageLayout.reportFrame.height, 184)
    }

    func testRealChatNamesContainingTechnicalWordsAreNotRewritten() {
        let technicalTitle = "Threading改善とSession管理"
        let technical = line(threadId: "technical", title: technicalTitle)
        let stage = PetKataribeStagePlanner.presentation(
            visibleBubbles: [bubble(for: technical)],
            conversationLines: [technical]
        )

        XCTAssertEqual(stage.report.threadTitle, technicalTitle)
        XCTAssertEqual(stage.charms.map(\.title), [technicalTitle])
    }

    func testFireflyCharmMotionStaysVisibleButSubtle() {
        let widthGrowth = PetKataribeStageLayout.charmWidth * (PetKataribeCharmMotion.breathingScale - 1)

        XCTAssertGreaterThan(widthGrowth, 1.5)
        XCTAssertLessThanOrEqual(widthGrowth, 3)
        XCTAssertEqual(PetKataribeCharmMotion.updatePulseCount, 2)
        XCTAssertEqual(PetKataribeCharmMotion.updatePulseHalfDuration, 0.38, accuracy: 0.001)
        XCTAssertGreaterThan(PetKataribeCharmMotion.feedInsertionOffsetY, 0)
        XCTAssertLessThan(PetKataribeCharmMotion.feedRemovalOffsetY, 0)
    }

    func testShortCharmRailsStayBottomAnchoredAndGrowUpward() {
        let oneChat = PetKataribeStageLayout.charmFrame(at: 0, totalCount: 1)
        let threeChats = (0..<3).map {
            PetKataribeStageLayout.charmFrame(at: $0, totalCount: 3)
        }
        let sixChats = (0..<6).map {
            PetKataribeStageLayout.charmFrame(at: $0, totalCount: 6)
        }

        XCTAssertEqual(oneChat.y, sixChats.last?.y)
        XCTAssertEqual(threeChats.last?.y, sixChats.last?.y)
        XCTAssertEqual(threeChats.map(\.y), Array(sixChats.suffix(3)).map(\.y))
    }

    func testCharmRailUsesTightVisibleSpacingAndEndsBesideMimo() {
        let charms = (0..<6).map { PetKataribeStageLayout.charmFrame(at: $0) }
        let visibleGaps = zip(charms, charms.dropFirst()).map { current, next in
            next.y - (current.y + current.height)
        }

        XCTAssertEqual(PetKataribeStageLayout.charmHeight, 29)
        XCTAssertEqual(visibleGaps, Array(repeating: 3, count: 5))
        XCTAssertEqual(charms.last?.y.advanced(by: charms.last?.height ?? 0), 269)
        XCTAssertEqual(PetKataribeStageLayout.reportBottom - 1, 269)
    }

    func testProductionFramesFitWithoutReportCharmOrSpriteOverlap() {
        let report = PetKataribeStageLayout.reportFrame
        let compactReport = PetKataribeStageLayout.reportFrame(forTextLength: 24)
        let sprite = PetKataribeStageLayout.spriteFrame
        let charms = (0..<6).map { PetKataribeStageLayout.charmFrame(at: $0) }

        XCTAssertTrue(isInsideWindow(report))
        XCTAssertTrue(isInsideWindow(compactReport))
        XCTAssertEqual(report.y + report.height, compactReport.y + compactReport.height)
        XCTAssertLessThan(compactReport.height, report.height)
        XCTAssertTrue(isInsideWindow(sprite))
        XCTAssertTrue(charms.allSatisfy(isInsideWindow))
        XCTAssertLessThanOrEqual(overlapHeight(report, sprite), 12)
        XCTAssertLessThanOrEqual(overlapHeight(compactReport, sprite), 12)
        XCTAssertTrue(charms.allSatisfy { !intersects(report, $0) })
        XCTAssertTrue(zip(charms, charms.dropFirst()).allSatisfy { !intersects($0, $1) })
    }

    func testGenericInternalReportTitleNeverReachesTheStageHeader() {
        let report = PetSpeechBubble(
            id: "thread:generic",
            text: "「Codex Thread」は検索画面の検証を進めているよ",
            role: .focus,
            tone: .active,
            threadId: "generic",
            threadTitle: "Codex Thread"
        )

        let stage = PetKataribeStagePlanner.presentation(
            visibleBubbles: [report],
            conversationLines: []
        )

        XCTAssertEqual(stage.report.threadTitle, "名前のないチャット")
    }

    private func line(
        threadId: String,
        title: String,
        text: String = "具体的な作業を進めているよ",
        activityKind: CodexConversationActivityKind = .assistantMessage
    ) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: title,
            speaker: "codex",
            text: text,
            isAssistant: true,
            activityKind: activityKind
        )
    }

    private func bubble(for line: CodexConversationLine) -> PetSpeechBubble {
        PetSpeechBubble(
            id: "thread:\(line.threadId)",
            text: "「\(line.threadTitle)」は具体的な作業を進めているよ",
            role: .focus,
            tone: .active,
            activityKind: line.activityKind,
            threadId: line.threadId,
            threadTitle: line.threadTitle
        )
    }

    private func isInsideWindow(_ frame: PetDragFrame) -> Bool {
        frame.x >= 0 && frame.y >= 0 &&
            frame.x + frame.width <= PetKataribeStageLayout.windowWidth &&
            frame.y + frame.height <= PetKataribeStageLayout.windowHeight
    }

    private func intersects(_ lhs: PetDragFrame, _ rhs: PetDragFrame) -> Bool {
        lhs.x < rhs.x + rhs.width && lhs.x + lhs.width > rhs.x &&
            lhs.y < rhs.y + rhs.height && lhs.y + lhs.height > rhs.y
    }

    private func overlapHeight(_ lhs: PetDragFrame, _ rhs: PetDragFrame) -> Double {
        max(0, min(lhs.y + lhs.height, rhs.y + rhs.height) - max(lhs.y, rhs.y))
    }
}
