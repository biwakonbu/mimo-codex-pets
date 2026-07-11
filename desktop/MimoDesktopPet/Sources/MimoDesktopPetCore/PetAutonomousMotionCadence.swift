import Foundation

public enum PetAutonomousMotionCadence {
    public static let activeFramesPerSecond = 60.0
    public static let restingFramesPerSecond = 4.0

    public static func interval(isActivelyMoving: Bool) -> TimeInterval {
        1.0 / (isActivelyMoving ? activeFramesPerSecond : restingFramesPerSecond)
    }
}
