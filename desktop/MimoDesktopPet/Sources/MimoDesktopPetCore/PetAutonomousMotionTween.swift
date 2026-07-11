import Foundation

public struct PetAutonomousTweenPosition: Equatable, Sendable {
    public var origin: PetWanderPoint
    public var progress: Double
    public var isComplete: Bool

    public init(origin: PetWanderPoint, progress: Double, isComplete: Bool) {
        self.origin = origin
        self.progress = progress
        self.isComplete = isComplete
    }
}

public struct PetAutonomousMotionTween: Equatable, Sendable {
    private static let smootherStepPeakVelocityFactor = 1.875
    public var start: PetWanderPoint
    public var target: PetWanderPoint
    public var startTime: TimeInterval
    public var duration: TimeInterval
    public var speedWaveAmplitude: Double
    public var speedWaveCycles: Double
    public var speedWavePhase: Double

    public init(
        start: PetWanderPoint,
        target: PetWanderPoint,
        startTime: TimeInterval,
        duration: TimeInterval,
        speedWaveAmplitude: Double = 0.12,
        speedWaveCycles: Double = 1.5,
        speedWavePhase: Double = 0
    ) {
        self.start = start
        self.target = target
        self.startTime = startTime
        self.duration = max(duration, 0.001)
        self.speedWaveAmplitude = min(max(speedWaveAmplitude, 0), 0.35)
        self.speedWaveCycles = max(speedWaveCycles, 0.001)
        self.speedWavePhase = speedWavePhase
    }

    public var directionAnimation: PetAnimationState {
        target.x < start.x ? .runningLeft : .runningRight
    }

    public static func make(
        start: PetWanderPoint,
        target: PetWanderPoint,
        startTime: TimeInterval,
        baseSpeed: Double,
        maximumSpeed: Double = 52,
        speedWaveAmplitude: Double,
        speedWaveCycles: Double,
        speedWavePhase: Double
    ) -> PetAutonomousMotionTween {
        let distance = hypot(target.x - start.x, target.y - start.y)
        let peakSpeed = min(max(baseSpeed, 1), max(maximumSpeed, 1))
        let averageSpeed = peakSpeed / smootherStepPeakVelocityFactor
        let duration = distance / averageSpeed
        return PetAutonomousMotionTween(
            start: start,
            target: target,
            startTime: startTime,
            duration: min(max(duration, 1.2), 30.0),
            speedWaveAmplitude: speedWaveAmplitude,
            speedWaveCycles: speedWaveCycles,
            speedWavePhase: speedWavePhase
        )
    }

    public func position(at time: TimeInterval) -> PetAutonomousTweenPosition {
        let rawUnit = (time - startTime) / duration
        if rawUnit <= 0 {
            return PetAutonomousTweenPosition(origin: start, progress: 0, isComplete: false)
        }
        if rawUnit >= 1 {
            return PetAutonomousTweenPosition(origin: target, progress: 1, isComplete: true)
        }

        let progress = smootherStep(monotonicWaveTime(rawUnit))
        return PetAutonomousTweenPosition(
            origin: PetWanderPoint(
                x: start.x + (target.x - start.x) * progress,
                y: start.y + (target.y - start.y) * progress
            ),
            progress: progress,
            isComplete: false
        )
    }

    private func monotonicWaveTime(_ unit: Double) -> Double {
        let clamped = min(max(unit, 0), 1)
        let angular = 2 * Double.pi * speedWaveCycles
        let amplitude = speedWaveAmplitude
        let integral = clamped + amplitude / angular * (
            cos(speedWavePhase) - cos(angular * clamped + speedWavePhase)
        )
        let total = 1 + amplitude / angular * (
            cos(speedWavePhase) - cos(angular + speedWavePhase)
        )
        guard total > 0 else { return clamped }
        return min(max(integral / total, 0), 1)
    }

    private func smootherStep(_ unit: Double) -> Double {
        let clamped = min(max(unit, 0), 1)
        return clamped * clamped * clamped * (clamped * (clamped * 6 - 15) + 10)
    }
}
