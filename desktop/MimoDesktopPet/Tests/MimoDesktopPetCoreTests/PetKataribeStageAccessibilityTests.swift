import XCTest
@testable import MimoDesktopPetCore

final class PetKataribeStageAccessibilityTests: XCTestCase {
    func testAccessibilityNamesAllSixChatsWithoutRawAnimationState() {
        let report = PetSpeechBubble(
            id: "thread:one",
            text: "「チャット 1」は検索画面のテストを進めているよ",
            role: .focus,
            tone: .active,
            threadId: "one",
            threadTitle: "チャット 1"
        )
        let charms = (1...6).map { index in
            PetKataribeChatCharm(
                threadId: "thread-\(index)",
                title: "チャット \(index)",
                tone: .active,
                activityKind: .test,
                isSelected: index == 1
            )
        }
        let value = PetKataribeStageAccessibility.value(
            stage: PetKataribeStagePresentation(report: report, charms: charms),
            debugOverlay: false
        )

        for index in 1...6 {
            XCTAssertTrue(value.contains("チャット \(index)"))
        }
        XCTAssertFalse(value.contains("running"))
        XCTAssertFalse(value.contains("active"))
    }
}
