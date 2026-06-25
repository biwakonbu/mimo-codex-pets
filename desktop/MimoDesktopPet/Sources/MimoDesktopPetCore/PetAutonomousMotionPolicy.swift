import Foundation

public enum PetAutonomousMotionPolicy {
    public static func shouldAllowWindowMovement(
        explicitWindowMovementEnabled: Bool,
        autonomousTestMode: Bool,
        autonomousEnergyTestMode: Bool,
        autonomousForceBegin: Bool
    ) -> Bool {
        explicitWindowMovementEnabled ||
            autonomousTestMode ||
            autonomousEnergyTestMode ||
            autonomousForceBegin
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

    public static func shouldHoldPositionForConversation(
        hasPendingConversationBubbles: Bool,
        autonomousTestMode: Bool,
        autonomousEnergyTestMode: Bool
    ) -> Bool {
        hasPendingConversationBubbles && !autonomousTestMode && !autonomousEnergyTestMode
    }

    public static func conversationHoldRestUntil(now: TimeInterval) -> TimeInterval {
        now + PetAutonomousMotionTuning.productionConversationHoldSeconds
    }
}
