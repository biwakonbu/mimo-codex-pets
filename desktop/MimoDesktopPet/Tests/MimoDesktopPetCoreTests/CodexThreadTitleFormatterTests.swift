import XCTest
@testable import MimoDesktopPetCore

final class CodexThreadTitleFormatterTests: XCTestCase {
    func testUsesFirstHumanLookingTitle() {
        let title = CodexThreadTitleFormatter.title(from: [
            "",
            "Mimo の本番表示を改善する"
        ])

        XCTAssertEqual(title, "Mimo の本番表示を改善する")
    }

    func testFallsBackWhenTitleLooksLikeInstructionContext() {
        let title = CodexThreadTitleFormatter.title(from: [
            "You are selected text from an instruction block",
            "<codex_internal_context source=\"goal\">Continue working"
        ])

        XCTAssertEqual(title, "Codex Thread")
    }

    func testTruncatesLongHumanTitle() {
        let title = CodexThreadTitleFormatter.title(from: [
            String(repeating: "長いタイトル", count: 10)
        ], limit: 12)

        XCTAssertLessThanOrEqual(title.count, 15)
        XCTAssertTrue(title.hasSuffix("..."))
    }
}
