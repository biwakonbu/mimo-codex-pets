import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleTextPartsTests: XCTestCase {
    func testParsesFocusedMimoReportIntoPrefixTitleAndSummary() {
        XCTAssertEqual(
            PetSpeechBubbleTextParts.parse("ご主人、「current」はコマンドを実行中です"),
            PetSpeechBubbleTextParts(
                prefix: "ご主人",
                threadTitle: "current",
                summary: "コマンドを実行中です"
            )
        )
    }

    func testParsesCompactThreadContextChipIntoTitleAndSummary() {
        XCTAssertEqual(
            PetSpeechBubbleTextParts.parse("「資料整理」作業中"),
            PetSpeechBubbleTextParts(
                prefix: nil,
                threadTitle: "資料整理",
                summary: "作業中"
            )
        )
    }

    func testKeepsPlainStatusAsSingleSummary() {
        XCTAssertEqual(
            PetSpeechBubbleTextParts.parse("Codex が作業中"),
            PetSpeechBubbleTextParts(
                prefix: nil,
                threadTitle: nil,
                summary: "Codex が作業中"
            )
        )
    }

    func testFallsBackWhenQuotedTitleIsEmpty() {
        XCTAssertEqual(
            PetSpeechBubbleTextParts.parse("「」作業中"),
            PetSpeechBubbleTextParts(
                prefix: nil,
                threadTitle: nil,
                summary: "「」作業中"
            )
        )
    }
}
