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

public struct PetAutonomousMovementBounds: Equatable, Sendable {
    public var minX: Double
    public var maxX: Double
    public var minY: Double
    public var maxY: Double

    public init(minX: Double, maxX: Double, minY: Double, maxY: Double) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
    }
}

public enum PetAutonomousMotionPlanner {
    public static func movementBounds(
        visibleFrame: PetDragFrame,
        petWidth: Double,
        petHeight: Double,
        margin: Double = 24
    ) -> PetAutonomousMovementBounds {
        let minX = visibleFrame.x + margin
        let minY = visibleFrame.y + margin
        return PetAutonomousMovementBounds(
            minX: minX,
            maxX: max(minX, visibleFrame.x + visibleFrame.width - petWidth - margin),
            minY: minY,
            maxY: max(minY, visibleFrame.y + visibleFrame.height - petHeight - margin)
        )
    }

    public static func target(
        visibleFrame: PetDragFrame,
        petWidth: Double,
        petHeight: Double,
        margin: Double = 24,
        randomX: Double,
        randomY: Double
    ) -> PetWanderPoint {
        let bounds = movementBounds(
            visibleFrame: visibleFrame,
            petWidth: petWidth,
            petHeight: petHeight,
            margin: margin
        )
        return PetWanderPoint(
            x: interpolate(from: bounds.minX, to: bounds.maxX, unit: randomX),
            y: interpolate(from: bounds.minY, to: bounds.maxY, unit: randomY)
        )
    }

    public static func limitedTarget(
        start: PetWanderPoint,
        rawTarget: PetWanderPoint,
        maximumDistance: Double
    ) -> PetWanderPoint {
        let deltaX = rawTarget.x - start.x
        let deltaY = rawTarget.y - start.y
        let distance = hypot(deltaX, deltaY)
        let limit = max(maximumDistance, 0)
        guard limit > 0, distance > limit else { return rawTarget }
        return PetWanderPoint(
            x: start.x + deltaX / distance * limit,
            y: start.y + deltaY / distance * limit
        )
    }

    public static func nearbyTarget(
        visibleFrame: PetDragFrame,
        petWidth: Double,
        petHeight: Double,
        start: PetWanderPoint,
        minimumDistance: Double,
        maximumDistance: Double,
        verticalScale: Double,
        angleUnit: Double,
        distanceUnit: Double
    ) -> PetWanderPoint {
        let bounds = movementBounds(
            visibleFrame: visibleFrame,
            petWidth: petWidth,
            petHeight: petHeight
        )
        let maximumDistance = max(0, maximumDistance)
        let minimumDistance = min(max(0, minimumDistance), maximumDistance)
        let easedDistanceUnit = pow(clampUnit(distanceUnit), 1.8)
        let distance = interpolate(
            from: minimumDistance,
            to: maximumDistance,
            unit: easedDistanceUnit
        )
        let angle = clampUnit(angleUnit) * 2 * Double.pi
        let proposed = PetWanderPoint(
            x: start.x + cos(angle) * distance,
            y: start.y + sin(angle) * distance * max(0, verticalScale)
        )

        return PetWanderPoint(
            x: clamp(proposed.x, minimum: bounds.minX, maximum: bounds.maxX),
            y: clamp(proposed.y, minimum: bounds.minY, maximum: bounds.maxY)
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
        start + (end - start) * clampUnit(unit)
    }

    private static func clampUnit(_ value: Double) -> Double {
        clamp(value, minimum: 0, maximum: 1)
    }

    private static func clamp(_ value: Double, minimum: Double, maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}
