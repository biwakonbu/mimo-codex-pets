import Foundation

public enum CodexConversationLineCombiner {
    public static func combinedConversationLines(
        threadDisplayOrder: [String],
        conversationByThread: [String: [CodexConversationLine]],
        threadActivityById: [String: CodexConversationLine],
        preferredThreadId: String?,
        limit: Int = 12
    ) -> [CodexConversationLine] {
        guard limit > 0 else { return [] }

        let bundles = threadDisplayOrder.compactMap { threadId -> ThreadLineBundle? in
            let recentLines = Array((conversationByThread[threadId] ?? []).suffix(3))
            let activity = threadActivityById[threadId]
            let lines = orderedLines(recentLines: recentLines, activity: activity)
            guard !lines.isEmpty else { return nil }
            return ThreadLineBundle(threadId: threadId, lines: lines)
        }

        let flattened = bundles.flatMap(\.lines)
        guard flattened.count > limit else { return flattened }

        let representatives = bundles.compactMap(\.representative)
        if representatives.count >= limit {
            return Array(representatives.suffix(limit))
        }

        var remainingExtraLineCount = limit - representatives.count
        var selectedExtraLinesByThread: [String: [CodexConversationLine]] = [:]

        for bundle in bundles.sortedForExtraLineSelection(preferredThreadId: preferredThreadId) {
            guard remainingExtraLineCount > 0 else { break }
            let extras = bundle.extraLines
            guard !extras.isEmpty else { continue }
            let selected = Array(extras.suffix(remainingExtraLineCount))
            selectedExtraLinesByThread[bundle.threadId] = selected
            remainingExtraLineCount -= selected.count
        }

        return bundles.flatMap { bundle in
            (selectedExtraLinesByThread[bundle.threadId] ?? []) + [bundle.representative]
        }
    }

    public static func orderedLines(
        recentLines: [CodexConversationLine],
        activity: CodexConversationLine?
    ) -> [CodexConversationLine] {
        guard let activity else { return recentLines }

        if CodexConversationBubblePlanner.displayPriority(for: activity) <= 2 {
            return recentLines + [activity]
        }

        if recentLines.contains(where: shouldPreferLineOverRoutineActivity) {
            return [activity] + recentLines
        }

        return recentLines + [activity]
    }

    private static func shouldPreferLineOverRoutineActivity(_ line: CodexConversationLine) -> Bool {
        if line.speaker == "you" {
            return false
        }
        if line.activityKind == .message, !line.isAssistant {
            return false
        }
        return line.activityKind != .message || line.isAssistant
    }
}

private struct ThreadLineBundle {
    let threadId: String
    let lines: [CodexConversationLine]

    var representative: CodexConversationLine {
        lines[lines.count - 1]
    }

    var extraLines: [CodexConversationLine] {
        Array(lines.dropLast())
    }
}

private extension Array where Element == ThreadLineBundle {
    func sortedForExtraLineSelection(preferredThreadId: String?) -> [ThreadLineBundle] {
        enumerated()
            .sorted { lhs, rhs in
                if let preferredThreadId {
                    let lhsPreferred = lhs.element.threadId == preferredThreadId
                    let rhsPreferred = rhs.element.threadId == preferredThreadId
                    if lhsPreferred != rhsPreferred {
                        return lhsPreferred
                    }
                }
                return lhs.offset > rhs.offset
            }
            .map(\.element)
    }
}
