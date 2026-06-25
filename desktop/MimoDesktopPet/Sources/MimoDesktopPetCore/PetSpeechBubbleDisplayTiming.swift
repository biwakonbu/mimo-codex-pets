import Foundation

public enum PetSpeechBubbleDisplayTiming {
    public static let testConversationBubbleDuration = 1.15
    public static let minimumConversationBubbleDuration = 16.0
    public static let readingDwellDuration = 4.5
    public static let maximumConversationBubbleDuration = 28.0

    public static func conversationBubbleDuration(
        for text: String,
        role: PetSpeechBubbleRole
    ) -> TimeInterval {
        let typewriterDuration = PetSpeechBubbleTypewriter.durationForBubbleText(for: text, role: role)
        let readableDuration = typewriterDuration + readingDwellDuration
        return min(
            maximumConversationBubbleDuration,
            max(minimumConversationBubbleDuration, readableDuration)
        )
    }
}
