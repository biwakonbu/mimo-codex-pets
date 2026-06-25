import Foundation

public enum PetAutonomousMotionTuning {
    public static let productionMaximumSpeed = 22.0
    public static let productionMinimumStepDistance = 10.0
    public static let productionMaximumStepDistance = 64.0
    public static let productionVerticalStepScale = 0.55
    public static let productionInitialRestSeconds = 7.0
    public static let productionBeginMotionProbability = 0.18
    public static let productionSpeedWaveAmplitudeRange = 0.02...0.07
    public static let productionSpeedWaveCyclesRange = 0.4...1.1
    public static let productionRetargetDelayRange = 24.0...52.0
    public static let productionIdleMomentDelayRange = 7.0...16.0
    public static let productionRestMomentDelayRange = 7.0...15.0
}
