import XCTest
@testable import MimoDesktopPetCore

final class ProcessSingleInstanceLockTests: XCTestCase {
    func testLockPathUsesExplicitEnvironmentOverride() {
        let path = ProcessSingleInstanceLock.lockPath(
            identifier: "com.example.App",
            environment: ["MIMO_SINGLE_INSTANCE_LOCK_PATH": "/tmp/mimo-explicit.lock"],
            temporaryDirectory: "/tmp/test-locks"
        )

        XCTAssertEqual(path, "/tmp/mimo-explicit.lock")
    }

    func testDefaultLockPathIsUserScopedAndSanitized() {
        let path = ProcessSingleInstanceLock.lockPath(
            identifier: "com.example App/Name",
            environment: [:],
            temporaryDirectory: "/tmp/test-locks"
        )

        XCTAssertTrue(path.hasPrefix("/tmp/test-locks/"))
        XCTAssertTrue(path.hasSuffix(".lock"))
        XCTAssertTrue(path.contains("com.example-App-Name"))
        XCTAssertFalse(path.contains(" "))
        XCTAssertFalse(path.contains("/Name"))
    }
}
