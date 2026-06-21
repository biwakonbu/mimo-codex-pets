import XCTest
@testable import MimoDesktopPetCore

final class CodexSessionSummarizerTests: XCTestCase {
    func testInfersBubbleSummaryWorkFromSessionContent() {
        XCTAssertEqual(
            CodexSessionSummarizer.summary(from: "吹き出しに Codex 作業内容の要約を出して状況を説明する"),
            "作業内容の説明"
        )
    }

    func testInfersConcreteProgressExplanationFromFeedback() {
        XCTAssertEqual(
            CodexSessionSummarizer.summary(from: "具体的にどんな事をやっているのか、考察や進捗を説明してほしい"),
            "進捗の具体説明"
        )
    }

    func testUsesSessionVocabularyForMultiChatSummaries() {
        XCTAssertEqual(
            CodexSessionSummarizer.summary(from: "複数スレッドの吹き出し表示を整理して"),
            "複数セッション表示"
        )
        XCTAssertEqual(
            CodexSessionSummarizer.summary(from: "セッションごとの吹き出し要約を準備して"),
            "セッション別の状況整理"
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
