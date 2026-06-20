import XCTest
@testable import MimoDesktopPetCore

final class PetInteractionHitRegionTests: XCTestCase {
    func testProductionHitRegionIncludesBubbleAndSprite() {
        let bounds = PetDragFrame(x: 0, y: 0, width: 360, height: 350)

        XCTAssertTrue(
            PetInteractionHitRegion.contains(
                point: PetWanderPoint(x: 180, y: 316),
                bounds: bounds,
                debugOverlay: false
            )
        )
        XCTAssertTrue(
            PetInteractionHitRegion.contains(
                point: PetWanderPoint(x: 180, y: 120),
                bounds: bounds,
                debugOverlay: false
            )
        )
    }

    func testProductionHitRegionRejectsTransparentCorners() {
        let bounds = PetDragFrame(x: 0, y: 0, width: 360, height: 350)

        XCTAssertFalse(
            PetInteractionHitRegion.contains(
                point: PetWanderPoint(x: 2, y: 2),
                bounds: bounds,
                debugOverlay: false
            )
        )
        XCTAssertFalse(
            PetInteractionHitRegion.contains(
                point: PetWanderPoint(x: 358, y: 80),
                bounds: bounds,
                debugOverlay: false
            )
        )
    }

    func testDebugOverlayAcceptsWholeWindow() {
        let bounds = PetDragFrame(x: 0, y: 0, width: 320, height: 430)

        XCTAssertTrue(
            PetInteractionHitRegion.contains(
                point: PetWanderPoint(x: 2, y: 2),
                bounds: bounds,
                debugOverlay: true
            )
        )
    }
}
