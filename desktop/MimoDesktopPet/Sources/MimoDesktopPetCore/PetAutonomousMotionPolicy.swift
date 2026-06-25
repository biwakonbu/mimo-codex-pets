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
