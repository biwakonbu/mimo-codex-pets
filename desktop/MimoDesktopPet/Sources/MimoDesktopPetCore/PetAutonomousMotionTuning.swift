import Foundation

public enum PetAutonomousMotionTuning {
    public static let productionMaximumSpeed = 7.0
    public static let productionMinimumStepDistance = 1.0
    public static let productionMaximumStepDistance = 12.0
    public static let productionVerticalStepScale = 0.18
    public static let productionInitialRestSeconds = 24.0
    public static let productionBeginMotionProbability = 0.018
    public static let productionSpeedWaveAmplitudeRange = 0.0...0.015
    public static let productionSpeedWaveCyclesRange = 0.15...0.45
    public static let productionRetargetDelayRange = 110.0...220.0
    public static let productionIdleMomentDelayRange = 5.0...14.0
    public static let productionRestMomentDelayRange = 20.0...50.0
    public static let productionConversationHoldSeconds = 30.0
}
