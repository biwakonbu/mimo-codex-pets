import Foundation

public enum PetAutonomousMotionTuning {
    public static let productionMaximumSpeed = 34.0
    public static let productionMaximumStepDistance = 96.0
    public static let productionInitialRestSeconds = 4.0
    public static let productionBeginMotionProbability = 0.30
    public static let productionSpeedWaveAmplitudeRange = 0.04...0.10
    public static let productionSpeedWaveCyclesRange = 0.7...1.5
    public static let productionRetargetDelayRange = 18.0...38.0
    public static let productionIdleMomentDelayRange = 5.5...12.5
    public static let productionRestMomentDelayRange = 5.0...11.0
}
