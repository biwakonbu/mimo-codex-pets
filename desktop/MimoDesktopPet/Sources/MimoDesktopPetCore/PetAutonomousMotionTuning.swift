import Foundation

public enum PetAutonomousMotionTuning {
    public static let productionMaximumSpeed = 34.0
    public static let productionMinimumStepDistance = 100.0
    public static let productionMaximumStepDistance = 280.0
    public static let productionHomeRadius = 560.0
    public static let productionVerticalStepScale = 0.55
    public static let productionInitialRestSeconds = 3.0
    public static let productionBeginMotionProbability = 0.96
    public static let productionSpeedWaveAmplitudeRange = 0.04...0.12
    public static let productionSpeedWaveCyclesRange = 0.7...1.5
    public static let productionRetargetDelayRange = 14.0...32.0
    public static let productionIdleMomentDelayRange = 3.0...8.0
    public static let productionRestMomentDelayRange = 4.0...10.0
    public static let productionAnchoredInitialMomentSeconds = 2.0
    public static let productionAnchoredIdleMomentDelayRange = 10.0...22.0
    public static let productionAnchoredRestMomentDelayRange = 12.0...28.0
}
