import XCTest
@testable import MimoDesktopPetCore

final class PetSpeechBubbleMotionPolicyTests: XCTestCase {
    func testBirthPulseTriggersWhenNewBubbleAppears() {
        XCTAssertTrue(PetSpeechBubbleMotionPolicy.shouldTriggerBirthPulse(
            previousIDs: ["a", "b"],
            nextIDs: ["a", "b", "c"]
        ))
    }

    func testBirthPulseTriggersWhenPrimaryBubbleIsReplaced() {
        XCTAssertTrue(PetSpeechBubbleMotionPolicy.shouldTriggerBirthPulse(
            previousIDs: ["old-primary", "b", "c"],
            nextIDs: ["new-primary", "b", "c"]
        ))
    }

    func testBirthPulseDoesNotTriggerForInitialRenderOrStableStack() {
        XCTAssertFalse(PetSpeechBubbleMotionPolicy.shouldTriggerBirthPulse(
            previousIDs: [],
            nextIDs: ["a"]
        ))
        XCTAssertFalse(PetSpeechBubbleMotionPolicy.shouldTriggerBirthPulse(
            previousIDs: ["a", "b"],
            nextIDs: ["a", "b"]
        ))
    }
}
