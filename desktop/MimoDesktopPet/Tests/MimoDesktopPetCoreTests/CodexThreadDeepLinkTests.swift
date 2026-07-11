import XCTest
@testable import MimoDesktopPetCore

final class CodexThreadDeepLinkTests: XCTestCase {
    func testBuildsCodexThreadURL() {
        let url = CodexThreadDeepLink.url(for: "019ee56d-5f73-7b21-b9f2-f78835179173")

        XCTAssertEqual(url?.absoluteString, "codex://threads/019ee56d-5f73-7b21-b9f2-f78835179173")
    }

    func testEncodesUnsafePathCharacters() {
        let url = CodexThreadDeepLink.url(for: "thread/with space")

        XCTAssertEqual(url?.absoluteString, "codex://threads/thread%2Fwith%20space")
    }

    func testRejectsEmptyThreadId() {
        XCTAssertNil(CodexThreadDeepLink.url(for: "  "))
    }
}
