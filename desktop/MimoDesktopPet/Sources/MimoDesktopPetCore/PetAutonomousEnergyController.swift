import Foundation

public struct PetAutonomousEnergyController: Equatable, Sendable {
    public static let defaultDrainPerSecond = 0.075
    public static let defaultRecoveryPerSecond = 0.42
    public static let fatiguePauseThreshold = 0.5
    public static let exhaustedThreshold = 0.16

    public private(set) var stamina: Double
    public var drainPerSecond: Double
    public var recoveryPerSecond: Double
    private var lastUpdateTime: TimeInterval?

    public init(
        stamina: Double = 1,
        drainPerSecond: Double = Self.defaultDrainPerSecond,
        recoveryPerSecond: Double = Self.defaultRecoveryPerSecond
    ) {
        self.stamina = Self.clampUnit(stamina)
        self.drainPerSecond = max(0, drainPerSecond)
        self.recoveryPerSecond = max(0.001, recoveryPerSecond)
    }

    public mutating func update(
        now: TimeInterval,
        isMoving: Bool,
        isResting: Bool
    ) {
        defer { lastUpdateTime = now }
        guard let lastUpdateTime else { return }

        let elapsed = min(max(now - lastUpdateTime, 0), 5)
        guard elapsed > 0 else { return }

        if isMoving {
            stamina = Self.clampUnit(stamina - drainPerSecond * elapsed)
        } else if isResting {
            stamina = Self.clampUnit(stamina + recoveryPerSecond * elapsed)
        }
    }

    public func speed(maximumSpeed: Double, moodUnit: Double) -> Double {
        let maximumSpeed = max(maximumSpeed, 1)
        let moodOffset = (Self.clampUnit(moodUnit) - 0.5) * 0.1
        let ratio = min(max(0.42 + 0.58 * stamina + moodOffset, 0.32), 1.0)
        return maximumSpeed * ratio
    }

    public func shouldPauseForRest(moodUnit: Double) -> Bool {
        if stamina <= Self.exhaustedThreshold {
            return true
        }
        guard stamina < Self.fatiguePauseThreshold else {
            return false
        }

        let fatigue = (Self.fatiguePauseThreshold - stamina) / Self.fatiguePauseThreshold
        let probability = min(max(0.22 + fatigue * 0.58, 0), 0.86)
        return Self.clampUnit(moodUnit) < probability
    }

    public func restDuration(moodUnit: Double) -> TimeInterval {
        let timeToFull = (1 - stamina) / recoveryPerSecond
        let moodPadding = 0.4 + Self.clampUnit(moodUnit) * 1.2
        return min(max(timeToFull + moodPadding, 0.8), 6.5)
    }

    private static func clampUnit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
