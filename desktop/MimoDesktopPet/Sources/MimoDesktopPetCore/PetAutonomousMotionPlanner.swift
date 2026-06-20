import Foundation

public struct PetWanderPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PetAutonomousStep: Equatable, Sendable {
    public var origin: PetWanderPoint
    public var reachedTarget: Bool

    public init(origin: PetWanderPoint, reachedTarget: Bool) {
        self.origin = origin
        self.reachedTarget = reachedTarget
    }
}

public enum PetAutonomousMotionPlanner {
    public static func target(
        visibleFrame: PetDragFrame,
        petWidth: Double,
        petHeight: Double,
        margin: Double = 24,
        randomX: Double,
        randomY: Double
    ) -> PetWanderPoint {
        let minX = visibleFrame.x + margin
        let minY = visibleFrame.y + margin
        let maxX = max(minX, visibleFrame.x + visibleFrame.width - petWidth - margin)
        let maxY = max(minY, visibleFrame.y + visibleFrame.height - petHeight - margin)
        return PetWanderPoint(
            x: interpolate(from: minX, to: maxX, unit: randomX),
            y: interpolate(from: minY, to: maxY, unit: randomY)
        )
    }

    public static func step(
        current: PetWanderPoint,
        target: PetWanderPoint,
        baseSpeed: Double,
        elapsed: TimeInterval,
        wave: Double,
        jitter: Double,
        arrivalDistance: Double = 3
    ) -> PetAutonomousStep {
        let deltaX = target.x - current.x
        let deltaY = target.y - current.y
        let distance = hypot(deltaX, deltaY)
        if distance <= arrivalDistance {
            return PetAutonomousStep(origin: current, reachedTarget: true)
        }

        let effectiveElapsed = min(max(elapsed, 0), 0.2)
        let effectiveSpeed = max(0, baseSpeed) * max(0, wave) * max(0, jitter)
        let travel = min(distance, effectiveSpeed * effectiveElapsed)
        guard travel > 0 else {
            return PetAutonomousStep(origin: current, reachedTarget: false)
        }

        return PetAutonomousStep(
            origin: PetWanderPoint(
                x: current.x + deltaX / distance * travel,
                y: current.y + deltaY / distance * travel
            ),
            reachedTarget: travel >= distance
        )
    }

    private static func interpolate(from start: Double, to end: Double, unit: Double) -> Double {
        let clamped = min(max(unit, 0), 1)
        return start + (end - start) * clamped
    }
}
