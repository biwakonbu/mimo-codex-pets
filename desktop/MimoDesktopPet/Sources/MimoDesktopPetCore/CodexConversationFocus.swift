import Foundation

public enum CodexConversationFocus {
    public static func select(
        from lines: [CodexConversationLine],
        preferredThreadId: String?
    ) -> CodexConversationLine? {
        if let preferredThreadId,
           let line = lines.last(where: { $0.threadId == preferredThreadId }) {
            return line
        }
        return lines.last
    }
}
