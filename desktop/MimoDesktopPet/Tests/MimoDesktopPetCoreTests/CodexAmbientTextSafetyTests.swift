import XCTest
@testable import MimoDesktopPetCore

final class CodexAmbientTextSafetyTests: XCTestCase {
    func testAllowsShortHumanStatusText() {
        XCTAssertFalse(CodexAmbientTextSafety.isUnsafeForAmbientDisplay("Mimo の吹き出しを確認"))
        XCTAssertFalse(CodexAmbientTextSafety.isUnsafeForAmbientDisplay("レビューできます"))
    }

    func testBlocksInstructionMachineAndSensitiveText() {
        let cases = [
            "<codex_internal_context source=\"goal\">Continue working</codex_internal_context>",
            #"{"stdout":"/Users/example/private/.env"}"#,
            "stdout: password=secret",
            "/Users/example/private/project/.env を確認",
            "Authorization: Bearer abcdef0123456789abcdef0123456789",
            "user@example.com の設定"
        ]

        for text in cases {
            XCTAssertTrue(CodexAmbientTextSafety.isUnsafeForAmbientDisplay(text), text)
        }
    }
}
