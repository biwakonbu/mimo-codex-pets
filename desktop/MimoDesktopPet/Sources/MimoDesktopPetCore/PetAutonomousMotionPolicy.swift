import Foundation

public enum PetAutonomousMotionPolicy {
    public static func shouldAllowWindowMovement(
        explicitWindowMovementEnabled: Bool?,
        autonomousTestMode: Bool,
        autonomousEnergyTestMode: Bool,
        autonomousForceBegin: Bool
    ) -> Bool {
        if autonomousTestMode || autonomousEnergyTestMode || autonomousForceBegin {
            return true
        }
        return explicitWindowMovementEnabled ?? true
    }

    public static func initialIdleMomentDelay(windowMovementEnabled: Bool) -> TimeInterval {
        windowMovementEnabled
            ? PetAutonomousMotionTuning.productionInitialRestSeconds
            : PetAutonomousMotionTuning.productionAnchoredInitialMomentSeconds
    }

    public static func idleMomentDelayRange(windowMovementEnabled: Bool) -> ClosedRange<TimeInterval> {
        windowMovementEnabled
            ? PetAutonomousMotionTuning.productionIdleMomentDelayRange
            : PetAutonomousMotionTuning.productionAnchoredIdleMomentDelayRange
    }

    public static func restMomentDelayRange(windowMovementEnabled: Bool) -> ClosedRange<TimeInterval> {
        windowMovementEnabled
            ? PetAutonomousMotionTuning.productionRestMomentDelayRange
            : PetAutonomousMotionTuning.productionAnchoredRestMomentDelayRange
    }

}
