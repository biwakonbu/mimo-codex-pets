import XCTest
@testable import MimoDesktopPetCore

final class CodexSessionSummarizerTests: XCTestCase {
    func testInfersBubbleSummaryWorkFromSessionContent() {
        XCTAssertEqual(
            CodexSessionSummarizer.summary(from: "吹き出しに Codex 作業内容の要約を出して状況を説明する"),
            "吹き出し要約"
        )
    }

    func testInfersMovementWorkFromSessionContent() {
        XCTAssertEqual(
            CodexSessionSummarizer.summary(from: "自律移動の速度と休憩タイミングを調整して"),
            "Mimo の動き"
        )
    }

    func testBlocksUnsafeSessionContent() {
        XCTAssertNil(
            CodexSessionSummarizer.summary(from: "/Users/example/private/project/.env Authorization: Bearer secret-token")
        )
    }
}
