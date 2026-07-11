import Foundation

public enum PetAutonomousMotionTuning {
    public static let productionMaximumSpeed = 34.0
    public static let productionMinimumStepDistance = 90.0
    public static let productionMaximumStepDistance = 240.0
    public static let productionHomeRadius = 360.0
    public static let productionVerticalStepScale = 0.35
    public static let productionInitialRestSeconds = 8.0
    public static let productionBeginMotionProbability = 0.72
    public static let productionSpeedWaveAmplitudeRange = 0.04...0.12
    public static let productionSpeedWaveCyclesRange = 0.7...1.5
    public static let productionRetargetDelayRange = 40.0...90.0
    public static let productionIdleMomentDelayRange = 3.0...8.0
    public static let productionRestMomentDelayRange = 4.0...10.0
    public static let productionAnchoredInitialMomentSeconds = 4.0
    public static let productionAnchoredIdleMomentDelayRange = 10.0...22.0
    public static let productionAnchoredRestMomentDelayRange = 12.0...28.0
}
