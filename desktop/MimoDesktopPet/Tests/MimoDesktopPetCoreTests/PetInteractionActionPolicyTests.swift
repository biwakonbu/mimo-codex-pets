import XCTest
@testable import MimoDesktopPetCore

final class PetInteractionActionPolicyTests: XCTestCase {
    func testSpriteStartsDrag() {
        XCTAssertEqual(
            PetInteractionActionPolicy.action(for: .sprite, debugOverlay: false),
            .dragSprite
        )
    }

    func testBubbleOnlyClicks() {
        XCTAssertEqual(
            PetInteractionActionPolicy.action(for: .bubble, debugOverlay: false),
            .clickBubble
        )
    }

    func testTransparentAreaIsIgnored() {
        XCTAssertEqual(
            PetInteractionActionPolicy.action(for: .none, debugOverlay: false),
            .ignore
        )
    }

    func testDebugOverlayRetainsWholeWindowDragForQa() {
        XCTAssertEqual(
            PetInteractionActionPolicy.action(for: .none, debugOverlay: true),
            .dragSprite
        )
    }

    func testTransparentAreaPassesPointerToApplicationBehindPet() {
        XCTAssertTrue(
            PetPointerPassThroughPolicy.ignoresMouseEvents(
                clickThrough: false,
                debugOverlay: false,
                isDragging: false,
                target: .none
            )
        )
    }

    func testSpriteAndBubbleKeepWindowInteractive() {
        for target in [PetInteractionHitTarget.sprite, .bubble] {
            XCTAssertFalse(
                PetPointerPassThroughPolicy.ignoresMouseEvents(
                    clickThrough: false,
                    debugOverlay: false,
                    isDragging: false,
                    target: target
                )
            )
        }
    }

    func testActiveDragDoesNotBecomeClickThrough() {
        XCTAssertFalse(
            PetPointerPassThroughPolicy.ignoresMouseEvents(
                clickThrough: false,
                debugOverlay: false,
                isDragging: true,
                target: .none
            )
        )
    }

    func testExplicitClickThroughOverridesInteractiveTargets() {
        XCTAssertTrue(
            PetPointerPassThroughPolicy.ignoresMouseEvents(
                clickThrough: true,
                debugOverlay: false,
                isDragging: false,
                target: .sprite
            )
        )
    }
}
