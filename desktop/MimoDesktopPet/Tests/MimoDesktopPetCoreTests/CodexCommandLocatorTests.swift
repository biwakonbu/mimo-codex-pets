import XCTest
@testable import MimoDesktopPetCore

final class CodexCommandLocatorTests: XCTestCase {
    func testMimoSpecificCodexExecutableOverrideWins() {
        let invocation = CodexCommandLocator.resolve(environment: [
            "MIMO_CODEX_EXECUTABLE": "/tmp/mimo-fake-codex",
            "CODEX_BIN": "/tmp/generic-codex",
            "HOME": "/tmp/mimo-home"
        ])

        XCTAssertEqual(invocation.executableURL.path, "/tmp/mimo-fake-codex")
        XCTAssertEqual(invocation.argumentsPrefix, [])
    }

    func testCodeBinOverrideStillWorksForExistingE2E() {
        let invocation = CodexCommandLocator.resolve(environment: [
            "CODEX_BIN": "/tmp/generic-codex",
            "HOME": "/tmp/mimo-home"
        ])

        XCTAssertEqual(invocation.executableURL.path, "/tmp/generic-codex")
        XCTAssertEqual(invocation.argumentsPrefix, [])
    }

    func testBlankExplicitOverridesFallBackToEnvCodex() {
        let invocation = CodexCommandLocator.resolve(environment: [
            "MIMO_CODEX_EXECUTABLE": "  ",
            "CODEX_BIN": "",
            "HOME": "/tmp/mimo-home-without-standalone-codex"
        ])

        XCTAssertEqual(invocation.executableURL.path, "/usr/bin/env")
        XCTAssertEqual(invocation.argumentsPrefix, ["codex"])
    }

    func testLaunchEnvironmentPrependsCodexSearchPaths() {
        let environment = CodexCommandLocator.launchEnvironment(base: [
            "HOME": "/Users/mimo",
            "PATH": "/custom/bin"
        ])

        XCTAssertEqual(
            environment["PATH"],
            "/Users/mimo/.volta/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/custom/bin"
        )
    }
}
