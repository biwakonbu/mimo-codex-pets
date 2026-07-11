import XCTest
@testable import MimoDesktopPetCore

final class CodexMimoDialogueCadencePolicyTests: XCTestCase {
    func testFirstOrganizationIsAllowedWithoutPreviousRun() {
        XCTAssertTrue(
            CodexMimoDialogueCadencePolicy.shouldOrganize(
                lastOrganizationAge: nil,
                interval: 30 * 60
            )
        )
    }

    func testOrganizationIsBlockedBeforeThirtyMinutes() {
        XCTAssertFalse(
            CodexMimoDialogueCadencePolicy.shouldOrganize(
                lastOrganizationAge: 30 * 60 - 1,
                interval: 30 * 60
            )
        )
    }

    func testOrganizationIsAllowedAtTheThirtyMinuteBoundary() {
        XCTAssertTrue(
            CodexMimoDialogueCadencePolicy.shouldOrganize(
                lastOrganizationAge: 30 * 60,
                interval: 30 * 60
            )
        )
    }
}
