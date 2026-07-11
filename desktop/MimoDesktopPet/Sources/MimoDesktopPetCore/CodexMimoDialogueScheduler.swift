import Foundation

public enum CodexMimoDialogueScheduler {
    public static func nextCandidate(
        from lines: [CodexConversationLine],
        preferredThreadId: String?,
        excludedKeys: Set<String>,
        throttledThreadIds: Set<String>
    ) -> CodexConversationLine? {
        CodexConversationBubblePlanner.orderedThreadUpdates(
            from: lines,
            preferredThreadId: preferredThreadId
        )
        .first { line in
            !excludedKeys.contains(CodexMimoDialoguePrompt.cacheKey(for: line)) &&
                !throttledThreadIds.contains(line.threadId)
        }
    }
}
