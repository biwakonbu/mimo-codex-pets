import XCTest
@testable import MimoDesktopPetCore

final class PetInteractionHitRegionTests: XCTestCase {
    func testProductionHitRegionIncludesBubbleAndSprite() {
        let bounds = productionBounds()

        XCTAssertTrue(
            PetInteractionHitRegion.contains(
                point: PetWanderPoint(x: 180, y: 326),
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
        let bounds = productionBounds()

        XCTAssertFalse(
            PetInteractionHitRegion.contains(
                point: PetWanderPoint(x: 2, y: 2),
                bounds: bounds,
                debugOverlay: false
            )
        )
        XCTAssertFalse(
            PetInteractionHitRegion.contains(
                point: PetWanderPoint(x: PetSpeechBubbleLayout.productionWindowWidth - 2, y: 80),
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

    private func productionBounds() -> PetDragFrame {
        PetDragFrame(
            x: 0,
            y: 0,
            width: PetSpeechBubbleLayout.productionWindowWidth,
            height: PetSpeechBubbleLayout.productionWindowHeight
        )
    }
}
