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
}
