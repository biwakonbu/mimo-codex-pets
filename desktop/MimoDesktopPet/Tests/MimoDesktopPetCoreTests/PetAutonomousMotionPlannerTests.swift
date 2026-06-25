import XCTest
@testable import MimoDesktopPetCore

final class PetAutonomousMotionPlannerTests: XCTestCase {
    func testProductionAutonomousTuningKeepsWanderGentle() {
        XCTAssertEqual(PetAutonomousMotionTuning.productionMaximumSpeed, 2.4)
        XCTAssertEqual(PetAutonomousMotionTuning.productionMinimumStepDistance, 1)
        XCTAssertLessThanOrEqual(PetAutonomousMotionTuning.productionMaximumStepDistance, 4)
        XCTAssertEqual(PetAutonomousMotionTuning.productionHomeRadius, 8)
        XCTAssertEqual(PetAutonomousMotionTuning.productionVerticalStepScale, 0.1)
        XCTAssertLessThanOrEqual(PetAutonomousMotionTuning.productionBeginMotionProbability, 0.004)
        XCTAssertGreaterThanOrEqual(PetAutonomousMotionTuning.productionInitialRestSeconds, 75)
        XCTAssertEqual(PetAutonomousMotionTuning.productionSpeedWaveAmplitudeRange, 0.0...0.006)
        XCTAssertEqual(PetAutonomousMotionTuning.productionSpeedWaveCyclesRange, 0.08...0.2)
        XCTAssertEqual(PetAutonomousMotionTuning.productionRetargetDelayRange, 260.0...520.0)
        XCTAssertEqual(PetAutonomousMotionTuning.productionIdleMomentDelayRange, 4.0...10.0)
        XCTAssertEqual(PetAutonomousMotionTuning.productionRestMomentDelayRange, 45.0...120.0)
        XCTAssertEqual(PetAutonomousMotionTuning.productionConversationHoldSeconds, 90)
    }

    func testProductionTuningStillCapsFallbackLongAutonomousSteps() {
        let target = PetAutonomousMotionPlanner.limitedTarget(
            start: PetWanderPoint(x: 10, y: 20),
            rawTarget: PetWanderPoint(x: 310, y: 420),
            maximumDistance: PetAutonomousMotionTuning.productionMaximumStepDistance
        )

        XCTAssertEqual(
            hypot(target.x - 10, target.y - 20),
            PetAutonomousMotionTuning.productionMaximumStepDistance,
            accuracy: 0.0001
        )
    }

    func testNearbyTargetChoosesShortWalkAroundCurrentPosition() {
        let visible = PetDragFrame(x: 0, y: 0, width: 900, height: 700)
        let start = PetWanderPoint(x: 220, y: 160)
        let target = PetAutonomousMotionPlanner.nearbyTarget(
            visibleFrame: visible,
            petWidth: 500,
            petHeight: 500,
            start: start,
            minimumDistance: PetAutonomousMotionTuning.productionMinimumStepDistance,
            maximumDistance: PetAutonomousMotionTuning.productionMaximumStepDistance,
            verticalScale: PetAutonomousMotionTuning.productionVerticalStepScale,
            angleUnit: 0,
            distanceUnit: 1
        )

        XCTAssertEqual(
            hypot(target.x - start.x, target.y - start.y),
            PetAutonomousMotionTuning.productionMaximumStepDistance,
            accuracy: 0.0001
        )
        XCTAssertEqual(target.y, start.y, accuracy: 0.0001)
    }

    func testNearbyTargetEasesDistanceTowardTinyWanders() {
        let visible = PetDragFrame(x: 0, y: 0, width: 900, height: 700)
        let start = PetWanderPoint(x: 220, y: 160)
        let target = PetAutonomousMotionPlanner.nearbyTarget(
            visibleFrame: visible,
            petWidth: 500,
            petHeight: 500,
            start: start,
            minimumDistance: PetAutonomousMotionTuning.productionMinimumStepDistance,
            maximumDistance: PetAutonomousMotionTuning.productionMaximumStepDistance,
            verticalScale: PetAutonomousMotionTuning.productionVerticalStepScale,
            angleUnit: 0,
            distanceUnit: 0.5
        )

        XCTAssertLessThan(hypot(target.x - start.x, target.y - start.y), 2)
    }

    func testHomeBoundedTargetStaysAroundHomeAcrossRepeatedSteps() {
        let visible = PetDragFrame(x: 0, y: 0, width: 900, height: 700)
        let home = PetWanderPoint(x: 220, y: 160)
        var start = home

        for index in 0..<100 {
            let target = PetAutonomousMotionPlanner.homeBoundedTarget(
                visibleFrame: visible,
                petWidth: 500,
                petHeight: 500,
                home: home,
                start: start,
                homeRadius: PetAutonomousMotionTuning.productionHomeRadius,
                minimumDistance: PetAutonomousMotionTuning.productionMinimumStepDistance,
                maximumStepDistance: PetAutonomousMotionTuning.productionMaximumStepDistance,
                verticalScale: PetAutonomousMotionTuning.productionVerticalStepScale,
                angleUnit: Double((index * 37) % 100) / 100.0,
                distanceUnit: Double((index * 53) % 100) / 100.0
            )

            XCTAssertLessThanOrEqual(
                hypot(target.x - home.x, target.y - home.y),
                PetAutonomousMotionTuning.productionHomeRadius + 0.0001
            )
            XCTAssertLessThanOrEqual(
                hypot(target.x - start.x, target.y - start.y),
                PetAutonomousMotionTuning.productionMaximumStepDistance + 0.0001
            )
            start = target
        }
    }

    func testHomeBoundedTargetMovesBackTowardHomeWhenOutsideRadius() {
        let visible = PetDragFrame(x: 0, y: 0, width: 900, height: 700)
        let home = PetWanderPoint(x: 220, y: 160)
        let start = PetWanderPoint(x: 260, y: 160)
        let target = PetAutonomousMotionPlanner.homeBoundedTarget(
            visibleFrame: visible,
            petWidth: 500,
            petHeight: 500,
            home: home,
            start: start,
            homeRadius: PetAutonomousMotionTuning.productionHomeRadius,
            minimumDistance: PetAutonomousMotionTuning.productionMinimumStepDistance,
            maximumStepDistance: PetAutonomousMotionTuning.productionMaximumStepDistance,
            verticalScale: PetAutonomousMotionTuning.productionVerticalStepScale,
            angleUnit: 0.25,
            distanceUnit: 1
        )

        XCTAssertLessThan(hypot(target.x - home.x, target.y - home.y), hypot(start.x - home.x, start.y - home.y))
        XCTAssertLessThanOrEqual(
            hypot(target.x - start.x, target.y - start.y),
            PetAutonomousMotionTuning.productionMaximumStepDistance + 0.0001
        )
    }

    func testNearbyTargetStaysInCurrentVisibleFrame() {
        let visible = PetDragFrame(x: 100, y: 200, width: 800, height: 600)
        let bounds = PetAutonomousMotionPlanner.movementBounds(
            visibleFrame: visible,
            petWidth: 500,
            petHeight: 500
        )
        let target = PetAutonomousMotionPlanner.nearbyTarget(
            visibleFrame: visible,
            petWidth: 500,
            petHeight: 500,
            start: PetWanderPoint(x: bounds.maxX, y: bounds.maxY),
            minimumDistance: PetAutonomousMotionTuning.productionMinimumStepDistance,
            maximumDistance: PetAutonomousMotionTuning.productionMaximumStepDistance,
            verticalScale: PetAutonomousMotionTuning.productionVerticalStepScale,
            angleUnit: 0.125,
            distanceUnit: 1
        )

        XCTAssertGreaterThanOrEqual(target.x, bounds.minX)
        XCTAssertLessThanOrEqual(target.x, bounds.maxX)
        XCTAssertGreaterThanOrEqual(target.y, bounds.minY)
        XCTAssertLessThanOrEqual(target.y, bounds.maxY)
    }

    func testTargetStaysInsideVisibleFrameWithPetSizeAndMargin() {
        let visible = PetDragFrame(x: 100, y: 200, width: 800, height: 600)
        let bounds = PetAutonomousMotionPlanner.movementBounds(
            visibleFrame: visible,
            petWidth: 320,
            petHeight: 430
        )

        let minimum = PetAutonomousMotionPlanner.target(
            visibleFrame: visible,
            petWidth: 320,
            petHeight: 430,
            randomX: -1,
            randomY: -1
        )
        let maximum = PetAutonomousMotionPlanner.target(
            visibleFrame: visible,
            petWidth: 320,
            petHeight: 430,
            randomX: 2,
            randomY: 2
        )

        XCTAssertEqual(bounds, PetAutonomousMovementBounds(minX: 124, maxX: 556, minY: 224, maxY: 346))
        XCTAssertEqual(minimum, PetWanderPoint(x: 124, y: 224))
        XCTAssertEqual(maximum, PetWanderPoint(x: 556, y: 346))
    }

    func testStepMovesTowardTargetWithoutOvershooting() {
        let update = PetAutonomousMotionPlanner.step(
            current: PetWanderPoint(x: 0, y: 0),
            target: PetWanderPoint(x: 100, y: 0),
            baseSpeed: 50,
            elapsed: 0.5,
            wave: 1,
            jitter: 1
        )

        XCTAssertFalse(update.reachedTarget)
        XCTAssertEqual(update.origin, PetWanderPoint(x: 10, y: 0))
    }

    func testStepReportsArrivalNearTarget() {
        let update = PetAutonomousMotionPlanner.step(
            current: PetWanderPoint(x: 98, y: 0),
            target: PetWanderPoint(x: 100, y: 0),
            baseSpeed: 50,
            elapsed: 0.1,
            wave: 1,
            jitter: 1
        )

        XCTAssertTrue(update.reachedTarget)
        XCTAssertEqual(update.origin, PetWanderPoint(x: 98, y: 0))
    }

    func testStepUsesWaveAndJitterAsSpeedVariation() {
        let update = PetAutonomousMotionPlanner.step(
            current: PetWanderPoint(x: 0, y: 0),
            target: PetWanderPoint(x: 100, y: 0),
            baseSpeed: 50,
            elapsed: 0.1,
            wave: 0.8,
            jitter: 1.5
        )

        XCTAssertEqual(update.origin.x, 6, accuracy: 0.0001)
        XCTAssertEqual(update.origin.y, 0, accuracy: 0.0001)
    }

    func testLimitedTargetCapsLongAutonomousSteps() {
        let target = PetAutonomousMotionPlanner.limitedTarget(
            start: PetWanderPoint(x: 10, y: 20),
            rawTarget: PetWanderPoint(x: 310, y: 420),
            maximumDistance: 100
        )

        XCTAssertEqual(hypot(target.x - 10, target.y - 20), 100, accuracy: 0.0001)
    }

    func testTweenMakeClampsMaximumSpeed() {
        let tween = PetAutonomousMotionTween.make(
            start: PetWanderPoint(x: 0, y: 0),
            target: PetWanderPoint(x: 104, y: 0),
            startTime: 0,
            baseSpeed: 900,
            maximumSpeed: 52,
            speedWaveAmplitude: 0.12,
            speedWaveCycles: 1.5,
            speedWavePhase: 0
        )

        XCTAssertEqual(tween.duration, 2, accuracy: 0.0001)
    }

    func testTweenDirectionAnimationFollowsHorizontalTarget() {
        let right = PetAutonomousMotionTween(
            start: PetWanderPoint(x: 10, y: 0),
            target: PetWanderPoint(x: 30, y: 100),
            startTime: 0,
            duration: 2
        )
        let left = PetAutonomousMotionTween(
            start: PetWanderPoint(x: 30, y: 0),
            target: PetWanderPoint(x: 10, y: 100),
            startTime: 0,
            duration: 2
        )
        let vertical = PetAutonomousMotionTween(
            start: PetWanderPoint(x: 30, y: 0),
            target: PetWanderPoint(x: 30, y: 100),
            startTime: 0,
            duration: 2
        )

        XCTAssertEqual(right.directionAnimation, .runningRight)
        XCTAssertEqual(left.directionAnimation, .runningLeft)
        XCTAssertEqual(vertical.directionAnimation, .runningRight)
    }

    func testTweenStartsAndEndsAtExpectedPoints() {
        let tween = PetAutonomousMotionTween(
            start: PetWanderPoint(x: 10, y: 20),
            target: PetWanderPoint(x: 110, y: 70),
            startTime: 5,
            duration: 4,
            speedWaveAmplitude: 0.14,
            speedWaveCycles: 1.5,
            speedWavePhase: 0.8
        )

        XCTAssertEqual(tween.position(at: 5).origin, PetWanderPoint(x: 10, y: 20))
        XCTAssertEqual(tween.position(at: 9).origin, PetWanderPoint(x: 110, y: 70))
        XCTAssertTrue(tween.position(at: 9).isComplete)
    }

    func testTweenMovesMonotonicallyWithoutOvershooting() {
        let tween = PetAutonomousMotionTween(
            start: PetWanderPoint(x: 0, y: 0),
            target: PetWanderPoint(x: 180, y: 0),
            startTime: 10,
            duration: 3,
            speedWaveAmplitude: 0.18,
            speedWaveCycles: 2.2,
            speedWavePhase: 1.1
        )

        var previous = tween.position(at: 10).origin.x
        for frame in 1...180 {
            let position = tween.position(at: 10 + Double(frame) / 60.0).origin.x
            XCTAssertGreaterThanOrEqual(position, previous - 0.0001)
            XCTAssertLessThanOrEqual(position, 180.0001)
            previous = position
        }
    }

    func testTweenHasSmoothStepDeltasAtDisplayCadence() {
        let tween = PetAutonomousMotionTween(
            start: PetWanderPoint(x: 0, y: 0),
            target: PetWanderPoint(x: 240, y: 0),
            startTime: 0,
            duration: 4,
            speedWaveAmplitude: 0.16,
            speedWaveCycles: 1.7,
            speedWavePhase: 0.4
        )

        var previousX = tween.position(at: 0).origin.x
        var previousDelta = 0.0
        var largestDeltaChange = 0.0
        var middleDelta = 0.0
        for frame in 1...240 {
            let time = Double(frame) / 60.0
            let x = tween.position(at: time).origin.x
            let delta = x - previousX
            if frame > 1 {
                largestDeltaChange = max(largestDeltaChange, abs(delta - previousDelta))
            }
            if frame == 120 {
                middleDelta = delta
            }
            previousX = x
            previousDelta = delta
        }

        let firstDelta = tween.position(at: 1.0 / 60.0).origin.x
        let lastDelta = 240 - tween.position(at: 4 - 1.0 / 60.0).origin.x
        XCTAssertLessThan(firstDelta, middleDelta)
        XCTAssertLessThan(lastDelta, middleDelta)
        XCTAssertLessThan(largestDeltaChange, 0.16)
    }
}
