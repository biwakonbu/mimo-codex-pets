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

    func testSkipsSensitiveAmbientTitlesAndUsesNextSafeCandidate() {
        let title = CodexThreadTitleFormatter.title(from: [
            "/Users/example/private/project/.env を確認",
            "https://example.com/private-token",
            "Mimo の表示品質を確認"
        ])

        XCTAssertEqual(title, "Mimo の表示品質を確認")
    }

    func testFallsBackForOnlySensitiveAmbientTitles() {
        let title = CodexThreadTitleFormatter.title(from: [
            "secret token 0123456789abcdef0123456789abcdef",
            "user@example.com の設定"
        ])

        XCTAssertEqual(title, "Codex Thread")
    }
}
