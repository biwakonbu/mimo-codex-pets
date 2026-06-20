import XCTest
@testable import MimoDesktopPetCore

final class PetWindowPlacementTests: XCTestCase {
    func testDefaultOriginPlacesPetNearLowerRight() {
        let origin = PetWindowPlacement.defaultOrigin(
            visibleFrame: PetDragFrame(x: 100, y: 200, width: 900, height: 700),
            petWidth: PetSpeechBubbleLayout.productionWindowWidth,
            petHeight: PetSpeechBubbleLayout.productionWindowHeight
        )

        XCTAssertEqual(origin, PetWanderPoint(x: 536, y: 280))
    }

    func testOriginOverrideParsesAndClampsToVisibleFrame() {
        let origin = PetWindowPlacement.origin(
            visibleFrame: PetDragFrame(x: 100, y: 200, width: 900, height: 700),
            petWidth: PetSpeechBubbleLayout.productionWindowWidth,
            petHeight: PetSpeechBubbleLayout.productionWindowHeight,
            override: "40,1200"
        )

        XCTAssertEqual(origin, PetWanderPoint(x: 100, y: 462))
    }

    func testInvalidOriginOverrideFallsBackToDefault() {
        let visible = PetDragFrame(x: 100, y: 200, width: 900, height: 700)

        XCTAssertEqual(
            PetWindowPlacement.origin(
                visibleFrame: visible,
                petWidth: PetSpeechBubbleLayout.productionWindowWidth,
                petHeight: PetSpeechBubbleLayout.productionWindowHeight,
                override: "left,top"
            ),
            PetWindowPlacement.defaultOrigin(
                visibleFrame: visible,
                petWidth: PetSpeechBubbleLayout.productionWindowWidth,
                petHeight: PetSpeechBubbleLayout.productionWindowHeight
            )
        )
    }

    func testParseOriginOverrideTrimsWhitespace() {
        XCTAssertEqual(
            PetWindowPlacement.parseOriginOverride(" 120.5, 240 "),
            PetWanderPoint(x: 120.5, y: 240)
        )
        XCTAssertNil(PetWindowPlacement.parseOriginOverride("120"))
        XCTAssertNil(PetWindowPlacement.parseOriginOverride(nil))
    }
}
