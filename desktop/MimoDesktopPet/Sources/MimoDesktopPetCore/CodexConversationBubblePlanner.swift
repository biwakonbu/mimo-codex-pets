import Foundation

public enum CodexConversationBubblePlanner {
    private struct BubbleCandidate: Equatable {
        let text: String
        let role: PetSpeechBubbleRole
        let tone: PetSpeechBubbleTone
        let activityKind: CodexConversationActivityKind?
    }

    public struct PrimaryBubble: Equatable, Sendable {
        public let text: String
        public let threadId: String?
        public let activityKind: CodexConversationActivityKind?

        public init(
            text: String,
            threadId: String?,
            activityKind: CodexConversationActivityKind? = nil
        ) {
            self.text = text
            self.threadId = threadId
            self.activityKind = activityKind
        }
    }

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
        return result.stableSortedByDisplayPriority()
    }

    public static func signature(for line: CodexConversationLine) -> String {
        "\(line.threadId)|\(line.speaker)|\(line.text)"
    }

    public static func displaySignature(for line: CodexConversationLine) -> String {
        "\(line.threadId)|\(CodexBubbleFormatter.bubbleText(for: line))"
    }

    public static func displayPriority(for line: CodexConversationLine) -> Int {
        let text = line.text.lowercased()
        if text.contains("失敗") || text.contains("エラー") || text.contains("failed") || text.contains("systemerror") {
            return 0
        }
        if text.contains("問題") || text.contains("警告") {
            return 0
        }
        if text.contains("承認確認済み") {
            return 2
        }
        if text.contains("確認待ち") || text.contains("待ち") || text.contains("入力") || text.contains("承認") || text.contains("安全") {
            return 1
        }
        if text.contains("レビュー可能") || text.contains("レビューでき") || text.contains("レビューを開始") {
            return 2
        }
        return 3
    }

    public static func tone(for line: CodexConversationLine) -> PetSpeechBubbleTone {
        switch displayPriority(for: line) {
        case 0:
            return .failed
        case 1:
            return .waiting
        case 2:
            return .review
        default:
            if line.speaker == "tool" || line.isAssistant {
                return .active
            }
            return .neutral
        }
    }

    public static func tone(forStatusText text: String) -> PetSpeechBubbleTone {
        let lowered = text.lowercased()
        if lowered.contains("失敗") || lowered.contains("エラー") || lowered.contains("failed") || lowered.contains("systemerror") {
            return .failed
        }
        if lowered.contains("問題") || lowered.contains("警告") {
            return .failed
        }
        if lowered.contains("承認確認済み") {
            return .review
        }
        if lowered.contains("確認待ち") || lowered.contains("確認を待") || lowered.contains("入力") || lowered.contains("承認") || lowered.contains("安全") {
            return .waiting
        }
        if lowered.contains("レビュー") || lowered.contains("完了") {
            return .review
        }
        if lowered.contains("作業") || lowered.contains("実行") || lowered.contains("検証") || lowered.contains("応答") || lowered.contains("計画") {
            return .active
        }
        return .neutral
    }

    public static func primaryBubble(
        statusText: String,
        conversationLines: [CodexConversationLine],
        preferredThreadId: String?,
        activeConversationThreadId: String? = nil,
        activeConversationActivityKind: CodexConversationActivityKind? = nil,
        isOffline: Bool = false
    ) -> PrimaryBubble {
        if let activeConversationThreadId {
            return PrimaryBubble(
                text: statusText,
                threadId: activeConversationThreadId,
                activityKind: activeConversationActivityKind
            )
        }

        if !isOffline,
           let focusedLine = primaryFocusLine(
            from: conversationLines,
            preferredThreadId: preferredThreadId
           ) {
            return PrimaryBubble(
                text: CodexBubbleFormatter.bubbleText(for: focusedLine),
                threadId: focusedLine.threadId,
                activityKind: focusedLine.activityKind
            )
        }

        return PrimaryBubble(text: statusText, threadId: nil)
    }

    public static func productionBubbles(
        primaryText: String,
        conversationLines: [CodexConversationLine],
        preferredThreadId: String?,
        primaryThreadId: String? = nil,
        primaryActivityKind: CodexConversationActivityKind? = nil,
        primaryRole: PetSpeechBubbleRole? = nil,
        limit: Int = PetSpeechBubbleLayout.productionVisibleLimit
    ) -> [PetSpeechBubble] {
        let visibleLimit = max(1, min(limit, PetSpeechBubbleLayout.productionVisibleLimit))
        var bubbles: [BubbleCandidate] = []
        var usedThreadIds = Set<String>()
        let resolvedPrimaryRole = primaryRole ?? (primaryThreadId == nil ? .status : .focus)
        let primary = CodexBubbleFormatter.compact(
            primaryText,
            limit: PetSpeechBubbleLayout.textLimit(for: resolvedPrimaryRole)
        )
        if !primary.isEmpty {
            bubbles.append(BubbleCandidate(
                text: primary,
                role: resolvedPrimaryRole,
                tone: tone(forStatusText: primary),
                activityKind: primaryActivityKind
            ))
        }
        if let primaryThreadId {
            usedThreadIds.insert(primaryThreadId)
        }

        let conversationLines = orderedThreadUpdates(
            from: conversationLines,
            preferredThreadId: preferredThreadId
        )
        var candidates: [BubbleCandidate] = []

        for line in conversationLines {
            guard !usedThreadIds.contains(line.threadId) else { continue }
            let text = CodexBubbleFormatter.contextText(for: line)
            let compacted = CodexBubbleFormatter.compact(
                text,
                limit: PetSpeechBubbleLayout.textLimit(for: .conversation)
            )
            guard !compacted.isEmpty,
                  !bubbles.contains(where: { $0.text == compacted }),
                  !candidates.contains(where: { $0.text == compacted })
            else { continue }
            candidates.append(BubbleCandidate(
                text: compacted,
                role: .conversation,
                tone: tone(for: line),
                activityKind: line.activityKind
            ))
            usedThreadIds.insert(line.threadId)
        }

        appendConversationContext(
            candidates,
            to: &bubbles,
            visibleLimit: visibleLimit
        )

        if bubbles.isEmpty {
            bubbles.append(BubbleCandidate(text: "待機中", role: .status, tone: .neutral, activityKind: nil))
        }

        return bubbles.prefix(visibleLimit).enumerated().map { index, bubble in
            PetSpeechBubble(
                id: "\(index)-\(bubble.role.rawValue)-\(bubble.activityKind?.rawValue ?? "none")-\(bubble.text)",
                text: bubble.text,
                role: bubble.role,
                tone: bubble.tone,
                activityKind: bubble.activityKind
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
        var signatures = Set(result.map(displaySignature(for:)))
        for line in lines {
            let signature = displaySignature(for: line)
            guard !signatures.contains(signature) else { continue }
            result.append(line)
            signatures.insert(signature)
        }
    }

    private static func appendConversationContext(
        _ candidates: [BubbleCandidate],
        to bubbles: inout [BubbleCandidate],
        visibleLimit: Int
    ) {
        let remainingSlots = visibleLimit - bubbles.count
        guard remainingSlots > 0, !candidates.isEmpty else { return }

        if candidates.count <= remainingSlots || remainingSlots == 1 {
            bubbles.append(contentsOf: candidates.prefix(remainingSlots))
            return
        }

        let visibleConversationCount = remainingSlots - 1
        bubbles.append(contentsOf: candidates.prefix(visibleConversationCount))
        let overflowCount = candidates.count - visibleConversationCount
        let overflowText = CodexBubbleFormatter.compact(
            "ほか\(overflowCount)件も見ています",
            limit: PetSpeechBubbleLayout.textLimit(for: .overflow)
        )
        if !overflowText.isEmpty {
            bubbles.append(BubbleCandidate(text: overflowText, role: .overflow, tone: .overflow, activityKind: nil))
        }
    }

    private static func primaryFocusLine(
        from lines: [CodexConversationLine],
        preferredThreadId: String?
    ) -> CodexConversationLine? {
        let focusedLine = CodexConversationFocus.select(
            from: lines,
            preferredThreadId: preferredThreadId
        )
        let focusedPriority = focusedLine.map(displayPriority(for:)) ?? 3
        guard focusedPriority > 0 else {
            return focusedLine
        }

        let actionableLine = orderedThreadUpdates(
            from: lines,
            preferredThreadId: preferredThreadId
        )
        .first { line in
            let priority = displayPriority(for: line)
            return priority < focusedPriority && priority <= 2
        }

        return actionableLine ?? focusedLine
    }

    private static func isProgressLine(_ line: CodexConversationLine) -> Bool {
        if line.speaker == "tool" {
            return true
        }
        return [
            "応答を作成中",
            "計画を整理中",
            "計画を更新中"
        ].contains(line.text)
    }
}

private extension Array where Element == CodexConversationLine {
    func stableSortedByDisplayPriority() -> [CodexConversationLine] {
        enumerated()
            .sorted { lhs, rhs in
                let lhsPriority = CodexConversationBubblePlanner.displayPriority(for: lhs.element)
                let rhsPriority = CodexConversationBubblePlanner.displayPriority(for: rhs.element)
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
