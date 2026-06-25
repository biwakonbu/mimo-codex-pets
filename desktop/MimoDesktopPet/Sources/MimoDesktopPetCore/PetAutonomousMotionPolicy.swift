import Foundation

public enum PetAutonomousMotionPolicy {
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
