import XCTest
@testable import MimoDesktopPetCore

final class CodexThreadTitleFormatterTests: XCTestCase {
    struct Fixture {
        let name: String
        let candidates: [Any]
        let expectedLimit16: String
        let expectedLimit12: String
    }

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

    func testThreadObjectUsesFirstUserPromptWhenNameAndPreviewAreMissing() {
        let title = CodexThreadTitleFormatter.title(fromThreadObject: [
            "id": "thread-1",
            "turns": [
                [
                    "items": [
                        [
                            "type": "userMessage",
                            "content": [
                                ["type": "inputText", "text": "Mimo の語り面を歩行中も読みやすくする"]
                            ]
                        ]
                    ]
                ]
            ]
        ])

        XCTAssertEqual(title, "Mimo の語り面を歩行中も読みやすくする")
    }

    func testThreadObjectPrefersExplicitNameOverUserPrompt() {
        let title = CodexThreadTitleFormatter.title(fromThreadObject: [
            "name": "かたりべステージ実装",
            "turns": [["input": "この文は名前に使わない"]]
        ])

        XCTAssertEqual(title, "かたりべステージ実装")
    }

    func testThreadObjectSkipsGenericPreviewAndUsesFirstUserPrompt() {
        let title = CodexThreadTitleFormatter.title(fromThreadObject: [
            "preview": "Codex Thread",
            "turns": [["input": "検索画面のページ送りを検証する"]]
        ])

        XCTAssertEqual(title, "検索画面のページ送りを検証する")
    }

    func testSharedSmokeTitleSanitizerFixturesMatchProductionFormatter() throws {
        for fixture in try loadSharedFixtures() {
            XCTAssertEqual(
                compactProductionTitle(fixture.candidates, limit: 16),
                fixture.expectedLimit16,
                fixture.name
            )
            XCTAssertEqual(
                compactProductionTitle(fixture.candidates, limit: 12),
                fixture.expectedLimit12,
                fixture.name
            )
        }
    }

    private func compactProductionTitle(_ candidates: [Any], limit: Int) -> String {
        let title = CodexThreadTitleFormatter.title(
            from: candidates,
            fallback: "Codex Thread",
            limit: limit
        )
        if ["Codex Thread", "unknown-thread"].contains(title) {
            return "Codex"
        }
        return title.isEmpty ? "Codex" : title
    }

    private func loadSharedFixtures() throws -> [Fixture] {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            let packageFile = directory.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageFile.path) {
                let fixtureURL = directory.appendingPathComponent("script/title_sanitizer_fixtures.json")
                let data = try Data(contentsOf: fixtureURL)
                let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                return try (raw ?? []).map { object in
                    guard
                        let name = object["name"] as? String,
                        let candidates = object["candidates"] as? [Any],
                        let expectedLimit16 = object["expectedLimit16"] as? String,
                        let expectedLimit12 = object["expectedLimit12"] as? String
                    else {
                        throw NSError(
                            domain: "CodexThreadTitleFormatterTests",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "invalid title sanitizer fixture: \(object)"]
                        )
                    }
                    return Fixture(
                        name: name,
                        candidates: candidates,
                        expectedLimit16: expectedLimit16,
                        expectedLimit12: expectedLimit12
                    )
                }
            }
            directory.deleteLastPathComponent()
        }
        throw NSError(
            domain: "CodexThreadTitleFormatterTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Package.swift not found from \(#filePath)"]
        )
    }
}
