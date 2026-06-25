import Foundation

public enum PetAutonomousMotionTuning {
    public static let productionMaximumSpeed = 5.0
    public static let productionMinimumStepDistance = 1.0
    public static let productionMaximumStepDistance = 8.0
    public static let productionHomeRadius = 16.0
    public static let productionVerticalStepScale = 0.14
    public static let productionInitialRestSeconds = 45.0
    public static let productionBeginMotionProbability = 0.01
    public static let productionSpeedWaveAmplitudeRange = 0.0...0.01
    public static let productionSpeedWaveCyclesRange = 0.1...0.3
    public static let productionRetargetDelayRange = 180.0...360.0
    public static let productionIdleMomentDelayRange = 4.0...10.0
    public static let productionRestMomentDelayRange = 35.0...90.0
    public static let productionConversationHoldSeconds = 45.0
}
