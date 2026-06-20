import Foundation

public enum CodexConversationBubblePlanner {
    public static func orderedThreadUpdates(
        from lines: [CodexConversationLine],
        preferredThreadId: String?
    ) -> [CodexConversationLine] {
        var latestByThread: [String: CodexConversationLine] = [:]
        var recencyOrder: [String] = []
        var preferredProgressLines: [CodexConversationLine] = []

        for line in lines where !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recencyOrder.removeAll { $0 == line.threadId }
            recencyOrder.append(line.threadId)
            latestByThread[line.threadId] = line
            if line.threadId == preferredThreadId, isProgressLine(line) {
                preferredProgressLines.append(line)
            }
        }

        var orderedIds = Array(recencyOrder.reversed())
        if let preferredThreadId,
           orderedIds.contains(preferredThreadId) {
            orderedIds.removeAll { $0 == preferredThreadId }
            orderedIds.insert(preferredThreadId, at: 0)
        }

        var result: [CodexConversationLine] = []
        appendUnique(preferredProgressLines, to: &result)
        appendUnique(orderedIds.compactMap { latestByThread[$0] }, to: &result)
        return result
    }

    public static func signature(for line: CodexConversationLine) -> String {
        "\(line.threadId)|\(line.speaker)|\(line.text)"
    }

    public static func productionBubbles(
        primaryText: String,
        conversationLines: [CodexConversationLine],
        preferredThreadId: String?,
        limit: Int = PetSpeechBubbleLayout.productionVisibleLimit
    ) -> [PetSpeechBubble] {
        let visibleLimit = max(1, min(limit, PetSpeechBubbleLayout.productionVisibleLimit))
        var texts: [String] = []
        let primary = CodexBubbleFormatter.compact(
            primaryText,
            limit: PetSpeechBubbleLayout.textLimit(for: .status)
        )
        if !primary.isEmpty {
            texts.append(primary)
        }

        let conversationTexts = orderedThreadUpdates(
            from: conversationLines,
            preferredThreadId: preferredThreadId
        ).map { CodexBubbleFormatter.bubbleText(for: $0) }

        for text in conversationTexts where texts.count < visibleLimit {
            let compacted = CodexBubbleFormatter.compact(
                text,
                limit: PetSpeechBubbleLayout.textLimit(for: .conversation)
            )
            guard !compacted.isEmpty, !texts.contains(compacted) else { continue }
            texts.append(compacted)
        }

        if texts.isEmpty {
            texts.append("待機中")
        }

        return texts.prefix(visibleLimit).enumerated().map { index, text in
            PetSpeechBubble(
                id: "\(index)-\(text)",
                text: text,
                role: index == 0 ? .status : .conversation
            )
        }
    }

    public static func insertionIndex(
        for line: CodexConversationLine,
        preferredThreadId: String?,
        pendingLines: [CodexConversationLine]
    ) -> Int {
        guard line.threadId == preferredThreadId else {
            return pendingLines.count
        }
        return pendingLines.firstIndex { $0.threadId != line.threadId } ?? pendingLines.count
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

    private static func appendUnique(_ lines: [CodexConversationLine], to result: inout [CodexConversationLine]) {
        var signatures = Set(result.map(signature(for:)))
        for line in lines {
            let signature = signature(for: line)
            guard !signatures.contains(signature) else { continue }
            result.append(line)
            signatures.insert(signature)
        }
    }

    private static func isProgressLine(_ line: CodexConversationLine) -> Bool {
        if line.speaker == "tool" {
            return true
        }
        return [
            "応答を作成中",
            "計画を整理中"
        ].contains(line.text)
    }
}
