import Foundation

public enum PetAutonomousMotionTuning {
    public static let productionMaximumSpeed = 14.0
    public static let productionMinimumStepDistance = 4.0
    public static let productionMaximumStepDistance = 28.0
    public static let productionVerticalStepScale = 0.35
    public static let productionInitialRestSeconds = 10.0
    public static let productionBeginMotionProbability = 0.08
    public static let productionSpeedWaveAmplitudeRange = 0.0...0.04
    public static let productionSpeedWaveCyclesRange = 0.25...0.8
    public static let productionRetargetDelayRange = 40.0...90.0
    public static let productionIdleMomentDelayRange = 8.0...20.0
    public static let productionRestMomentDelayRange = 12.0...26.0
}
