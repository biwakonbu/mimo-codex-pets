import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleTypewriterTests: XCTestCase {
    func testEmptyTextStaysEmpty() {
        XCTAssertEqual(PetSpeechBubbleTypewriter.visiblePrefix(for: "", elapsed: 0), "")
        XCTAssertEqual(PetSpeechBubbleTypewriter.revealedCharacterCount(for: "", elapsed: 1), 0)
        XCTAssertEqual(PetSpeechBubbleTypewriter.duration(for: ""), 0)
    }

    func testFirstCharacterAppearsImmediately() {
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visiblePrefix(for: "mimo", elapsed: 0, charactersPerSecond: 10),
            "m"
        )
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visiblePrefix(for: "mimo", elapsed: -1, charactersPerSecond: 10),
            "m"
        )
    }

    func testCharactersRevealAtConfiguredPace() {
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visiblePrefix(for: "mimo", elapsed: 0.19, charactersPerSecond: 10),
            "mi"
        )
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visiblePrefix(for: "mimo", elapsed: 0.2, charactersPerSecond: 10),
            "mim"
        )
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visiblePrefix(for: "mimo", elapsed: 1, charactersPerSecond: 10),
            "mimo"
        )
    }

    func testDurationReachesLastCharacter() {
        let text = "mimo"
        let duration = PetSpeechBubbleTypewriter.duration(for: text, charactersPerSecond: 10)

        XCTAssertEqual(duration, 0.3, accuracy: 0.0001)
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visiblePrefix(for: text, elapsed: duration, charactersPerSecond: 10),
            text
        )
    }

    func testComposedCharactersRevealAsCharacters() {
        let text = "ミモが話す"

        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visiblePrefix(for: text, elapsed: 0, charactersPerSecond: 4),
            "ミ"
        )
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visiblePrefix(for: text, elapsed: 0.5, charactersPerSecond: 4),
            "ミモが"
        )
    }

    func testNonPositiveSpeedRevealsEverything() {
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visiblePrefix(for: "mimo", elapsed: 0, charactersPerSecond: 0),
            "mimo"
        )
    }

    func testFocusedBubbleKeepsChatTitleVisibleWhileSummaryReveals() {
        let text = "「UI 修正」吹き出しを調整しているの"

        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visibleBubbleText(
                for: text,
                role: .focus,
                elapsed: 0,
                charactersPerSecond: 10
            ),
            "「UI 修正」吹"
        )
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visibleBubbleText(
                for: text,
                role: .focus,
                elapsed: 10,
                charactersPerSecond: 10
            ),
            text
        )
    }

    func testConversationBubbleKeepsPrefixAndTitleVisible() {
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.visibleBubbleText(
                for: "mimo、「動作確認」は進捗をまとめているの",
                role: .conversation,
                elapsed: 0.1,
                charactersPerSecond: 10
            ),
            "mimo、「動作確認」進捗"
        )
    }

    func testBubbleDurationUsesSummaryWhenTitleIsVisible() {
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.durationForBubbleText(
                for: "mimo、「動作確認」は進捗",
                role: .conversation,
                charactersPerSecond: 10
            ),
            0.1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PetSpeechBubbleTypewriter.durationForBubbleText(
                for: "mimo、「動作確認」は進捗",
                role: .status,
                charactersPerSecond: 10
            ),
            1.3,
            accuracy: 0.0001
        )
    }
}
