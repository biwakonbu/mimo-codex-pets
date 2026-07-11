import Foundation

public enum PetAutonomousMotionAnimationPolicy {
    public static let productionActivationDistance = 8.0

    public static func animation(
        for motion: PetAutonomousMotionTween,
        currentOrigin: PetWanderPoint,
        isAlreadyAnimating: Bool,
        activationDistance: Double = productionActivationDistance
    ) -> PetAnimationState? {
        let traveled = hypot(
            currentOrigin.x - motion.start.x,
            currentOrigin.y - motion.start.y
        )
        guard isAlreadyAnimating || traveled >= max(0, activationDistance) else {
            return nil
        }
        return motion.directionAnimation
    }
}
