import XCTest
@testable import MimoDesktopPetCore

final class PetInteractionHitRegionTests: XCTestCase {
    func testProductionHitRegionSeparatesSpriteAndBubble() {
        let bounds = productionBounds()

        XCTAssertEqual(
            PetInteractionHitRegion.target(
                point: PetWanderPoint(x: 180, y: 326),
                bounds: bounds,
                bubbleFrames: [PetDragFrame(x: 80, y: 280, width: 360, height: 100)],
                debugOverlay: false
            ),
            .bubble
        )
        XCTAssertEqual(
            PetInteractionHitRegion.target(
                point: PetWanderPoint(x: 180, y: 120),
                bounds: bounds,
                bubbleFrames: [],
                debugOverlay: false
            ),
            .sprite
        )
    }

    func testProductionHitRegionRejectsTransparentCorners() {
        let bounds = productionBounds()

        XCTAssertEqual(
            PetInteractionHitRegion.target(
                point: PetWanderPoint(x: 2, y: 2),
                bounds: bounds,
                bubbleFrames: [],
                debugOverlay: false
            ),
            .none
        )
        XCTAssertEqual(
            PetInteractionHitRegion.target(
                point: PetWanderPoint(x: PetSpeechBubbleLayout.productionWindowWidth - 2, y: 80),
                bounds: bounds,
                bubbleFrames: [],
                debugOverlay: false
            ),
            .none
        )
    }

    func testSpriteRegionRejectsTransparentSpaceInsideSpriteFrame() {
        let bounds = productionBounds()

        XCTAssertEqual(
            PetInteractionHitRegion.target(
                point: PetWanderPoint(x: 140, y: 120),
                bounds: bounds,
                bubbleFrames: [],
                debugOverlay: false
            ),
            .none
        )
    }

    func testSpriteAlphaMaskOverridesFallbackShape() throws {
        let bounds = productionBounds()
        let transparentMask = try XCTUnwrap(PetSpriteAlphaMask(
            width: 1,
            height: 1,
            alphaValues: [0]
        ))
        let opaqueMask = try XCTUnwrap(PetSpriteAlphaMask(
            width: 1,
            height: 1,
            alphaValues: [255]
        ))
        let point = PetWanderPoint(x: 246, y: 140)

        XCTAssertEqual(
            PetInteractionHitRegion.target(
                point: point,
                bounds: bounds,
                bubbleFrames: [],
                debugOverlay: false,
                spriteAlphaMask: transparentMask
            ),
            .none
        )
        XCTAssertEqual(
            PetInteractionHitRegion.target(
                point: point,
                bounds: bounds,
                bubbleFrames: [],
                debugOverlay: false,
                spriteAlphaMask: opaqueMask
            ),
            .sprite
        )
    }

    func testBubbleCornerIsNotInteractiveOutsideRoundedShape() {
        let bounds = productionBounds()
        let bubbleFrame = PetDragFrame(x: 80, y: 280, width: 360, height: 100)

        XCTAssertEqual(
            PetInteractionHitRegion.target(
                point: PetWanderPoint(x: 81, y: 281),
                bounds: bounds,
                bubbleFrames: [bubbleFrame],
                debugOverlay: false
            ),
            .none
        )
        XCTAssertEqual(
            PetInteractionHitRegion.target(
                point: PetWanderPoint(x: 260, y: 330),
                bounds: bounds,
                bubbleFrames: [bubbleFrame],
                debugOverlay: false
            ),
            .bubble
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
