import Foundation

public enum PetAutonomousMotionTuning {
    public static let productionMaximumSpeed = 2.4
    public static let productionMinimumStepDistance = 1.0
    public static let productionMaximumStepDistance = 4.0
    public static let productionHomeRadius = 8.0
    public static let productionVerticalStepScale = 0.1
    public static let productionInitialRestSeconds = 75.0
    public static let productionBeginMotionProbability = 0.004
    public static let productionSpeedWaveAmplitudeRange = 0.0...0.006
    public static let productionSpeedWaveCyclesRange = 0.08...0.2
    public static let productionRetargetDelayRange = 260.0...520.0
    public static let productionIdleMomentDelayRange = 4.0...10.0
    public static let productionRestMomentDelayRange = 45.0...120.0
    public static let productionConversationHoldSeconds = 90.0
    public static let productionAnchoredInitialMomentSeconds = 8.0
    public static let productionAnchoredIdleMomentDelayRange = 18.0...34.0
    public static let productionAnchoredRestMomentDelayRange = 22.0...48.0
}
