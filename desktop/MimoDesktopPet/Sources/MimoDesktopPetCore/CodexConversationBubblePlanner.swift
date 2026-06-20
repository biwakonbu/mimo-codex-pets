import Foundation

public enum CodexConversationBubblePlanner {
    public static func orderedThreadUpdates(
        from lines: [CodexConversationLine],
        preferredThreadId: String?
    ) -> [CodexConversationLine] {
        var latestByThread: [String: CodexConversationLine] = [:]
        var recencyOrder: [String] = []

        for line in lines where !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recencyOrder.removeAll { $0 == line.threadId }
            recencyOrder.append(line.threadId)
            latestByThread[line.threadId] = line
        }

        var orderedIds = Array(recencyOrder.reversed())
        if let preferredThreadId,
           orderedIds.contains(preferredThreadId) {
            orderedIds.removeAll { $0 == preferredThreadId }
            orderedIds.insert(preferredThreadId, at: 0)
        }

        return orderedIds.compactMap { latestByThread[$0] }
    }

    public static func signature(for line: CodexConversationLine) -> String {
        "\(line.threadId)|\(line.speaker)|\(line.text)"
    }

    public static func animation(
        for line: CodexConversationLine,
        fallback: PetAnimationState
    ) -> PetAnimationState {
        guard fallback == .idle else { return fallback }
        if line.speaker == "you" || line.speaker == "thread" {
            return .waving
        }
        if line.isAssistant || line.speaker == "tool" {
            return .review
        }
        return fallback
    }
}
