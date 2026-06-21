import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubblePaginatorTests: XCTestCase {
    func testShortTextStaysOnOnePage() {
        XCTAssertEqual(
            PetSpeechBubblePaginator.pages(for: "ご主人、短い報告です", role: .focus, limit: 24),
            ["ご主人、短い報告です"]
        )
    }

    func testLongTextSplitsAtReadablePunctuation() {
        let pages = PetSpeechBubblePaginator.pages(
            for: "ご主人、「実装」は動作中です。Codex が吹き出しの幅と高さを広げています。Mimo は長い説明を読みやすいページに分けます。",
            role: .focus,
            limit: 36
        )

        XCTAssertGreaterThan(pages.count, 1)
        XCTAssertTrue(pages.allSatisfy { $0.count <= 36 })
        XCTAssertEqual(
            pages.joined(),
            "ご主人、「実装」は動作中です。Codex が吹き出しの幅と高さを広げています。Mimo は長い説明を読みやすいページに分けます。"
        )
    }

    func testLongUnbrokenTextFallsBackToHardLimit() {
        let pages = PetSpeechBubblePaginator.pages(
            for: String(repeating: "会話スキット", count: 12),
            role: .focus,
            limit: 20
        )

        XCTAssertGreaterThan(pages.count, 1)
        XCTAssertTrue(pages.allSatisfy { $0.count <= 20 })
    }
}
