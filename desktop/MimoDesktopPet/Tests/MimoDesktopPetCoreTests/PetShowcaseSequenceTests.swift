import XCTest
@testable import MimoDesktopPetCore

final class PetShowcaseSequenceTests: XCTestCase {
    func testShowcaseCoversEveryPetAnimationState() {
        XCTAssertEqual(PetShowcaseSequence.coveredAnimations, Set(PetAnimationState.allCases))
    }

    func testShowcaseKeepsEachSceneVisibleLongEnoughForASpriteLoop() {
        let minimumLoopDuration = 8.0 * 0.36

        for scene in PetShowcaseSequence.scenes {
            XCTAssertGreaterThanOrEqual(scene.duration, PetShowcaseSequence.minimumSceneDuration)
            XCTAssertGreaterThanOrEqual(scene.duration, minimumLoopDuration)
        }
    }

    func testShowcaseBuildsProgressiveBubbleStackForBirthPushMotion() {
        var coordinator = PetPresentationCoordinator()
        let counts = PetShowcaseSequence.scenes.prefix(4).map { scene in
            coordinator.apply(showcaseScene: scene)
            return coordinator.visibleBubbles.count
        }

        XCTAssertEqual(counts, [1, 2, 3, 4])
    }

    func testShowcaseUsesReadableChatNamesInsteadOfGenericSessionLabels() {
        for scene in PetShowcaseSequence.scenes {
            XCTAssertFalse(scene.bubbleText.contains("Codex Session"))
            XCTAssertFalse(scene.bubbleText.contains("Codex Thread"))
            XCTAssertFalse(scene.bubbleText.contains("スレッド"))
            for line in scene.conversationLines {
                XCTAssertFalse(line.threadTitle.contains("Codex Session"))
                XCTAssertFalse(line.threadTitle.contains("Codex Thread"))
                XCTAssertFalse(line.threadTitle.contains("スレッド"))
            }
        }
    }
}
