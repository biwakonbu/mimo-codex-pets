import Foundation

public enum PetAutonomousMotionFrameLimiter {
    public static func limitedOrigin(
        current: PetWanderPoint,
        desired: PetWanderPoint,
        maximumSpeed: Double,
        elapsed: TimeInterval
    ) -> PetWanderPoint {
        let deltaX = desired.x - current.x
        let deltaY = desired.y - current.y
        let distance = hypot(deltaX, deltaY)
        guard distance > 0 else { return desired }

        let safeElapsed = min(max(elapsed, 0), 1.0 / 10.0)
        let maximumTravel = max(0, maximumSpeed) * safeElapsed
        guard maximumTravel > 0 else { return current }
        guard distance > maximumTravel else { return desired }

        return PetWanderPoint(
            x: current.x + deltaX / distance * maximumTravel,
            y: current.y + deltaY / distance * maximumTravel
        )
    }
}
