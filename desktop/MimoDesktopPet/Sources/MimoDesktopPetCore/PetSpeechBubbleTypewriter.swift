import Foundation

public enum PetSpeechBubbleTypewriter {
    public static func visibleBubbleText(
        for text: String,
        role: PetSpeechBubbleRole,
        elapsed: TimeInterval,
        charactersPerSecond: Double = PetSpeechBubbleLayout.typewriterCharactersPerSecond
    ) -> String {
        guard role == .focus || role == .conversation else {
            return visiblePrefix(
                for: text,
                elapsed: elapsed,
                charactersPerSecond: charactersPerSecond
            )
        }

        let parts = PetSpeechBubbleTextParts.parse(text)
        guard let threadTitle = parts.threadTitle, !parts.summary.isEmpty else {
            return visiblePrefix(
                for: text,
                elapsed: elapsed,
                charactersPerSecond: charactersPerSecond
            )
        }

        let visibleSummary = visiblePrefix(
            for: parts.summary,
            elapsed: elapsed,
            charactersPerSecond: charactersPerSecond
        )
        return composedBubbleText(
            prefix: parts.prefix,
            threadTitle: threadTitle,
            summary: visibleSummary
        )
    }

    public static func visiblePrefix(
        for text: String,
        elapsed: TimeInterval,
        charactersPerSecond: Double = PetSpeechBubbleLayout.typewriterCharactersPerSecond
    ) -> String {
        let count = revealedCharacterCount(
            for: text,
            elapsed: elapsed,
            charactersPerSecond: charactersPerSecond
        )
        guard count < text.count else { return text }
        return String(text.prefix(count))
    }

    public static func revealedCharacterCount(
        for text: String,
        elapsed: TimeInterval,
        charactersPerSecond: Double = PetSpeechBubbleLayout.typewriterCharactersPerSecond
    ) -> Int {
        guard !text.isEmpty else { return 0 }
        guard charactersPerSecond > 0 else { return text.count }

        let safeElapsed = max(0, elapsed)
        let revealed = Int(floor(safeElapsed * charactersPerSecond)) + 1
        return min(text.count, max(1, revealed))
    }

    public static func duration(
        for text: String,
        charactersPerSecond: Double = PetSpeechBubbleLayout.typewriterCharactersPerSecond
    ) -> TimeInterval {
        guard !text.isEmpty else { return 0 }
        guard charactersPerSecond > 0 else { return 0 }
        return TimeInterval(max(0, text.count - 1)) / charactersPerSecond
    }

    public static func durationForBubbleText(
        for text: String,
        role: PetSpeechBubbleRole,
        charactersPerSecond: Double = PetSpeechBubbleLayout.typewriterCharactersPerSecond
    ) -> TimeInterval {
        guard role == .focus || role == .conversation else {
            return duration(for: text, charactersPerSecond: charactersPerSecond)
        }

        let parts = PetSpeechBubbleTextParts.parse(text)
        guard parts.threadTitle != nil, !parts.summary.isEmpty else {
            return duration(for: text, charactersPerSecond: charactersPerSecond)
        }
        return duration(for: parts.summary, charactersPerSecond: charactersPerSecond)
    }

    private static func composedBubbleText(prefix: String?, threadTitle: String, summary: String) -> String {
        let prefixText = prefix.map { "\($0)、" } ?? ""
        return "\(prefixText)「\(threadTitle)」\(summary)"
    }
}
