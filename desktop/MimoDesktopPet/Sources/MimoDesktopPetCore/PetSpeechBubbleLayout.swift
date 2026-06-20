import Foundation

public enum PetSpeechBubbleLayout {
    public static let productionVisibleLimit = 3
    public static let statusTextLimit = 44
    public static let conversationTextLimit = 34

    public static func textLimit(for role: PetSpeechBubbleRole) -> Int {
        switch role {
        case .status:
            return statusTextLimit
        case .conversation:
            return conversationTextLimit
        }
    }

    public static func lineLimit(for role: PetSpeechBubbleRole) -> Int {
        switch role {
        case .status:
            return 2
        case .conversation:
            return 1
        }
    }
}
