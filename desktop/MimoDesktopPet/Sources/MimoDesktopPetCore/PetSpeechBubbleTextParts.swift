import Foundation

public struct PetSpeechBubbleTextParts: Equatable, Sendable {
    public let prefix: String?
    public let threadTitle: String?
    public let summary: String

    public init(prefix: String?, threadTitle: String?, summary: String) {
        self.prefix = prefix
        self.threadTitle = threadTitle
        self.summary = summary
    }

    public static func parse(_ text: String) -> PetSpeechBubbleTextParts {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else {
            return PetSpeechBubbleTextParts(prefix: nil, threadTitle: nil, summary: "")
        }
        guard
            let openQuote = collapsed.firstIndex(of: "「"),
            let closeQuote = collapsed[collapsed.index(after: openQuote)...].firstIndex(of: "」")
        else {
            return PetSpeechBubbleTextParts(prefix: nil, threadTitle: nil, summary: collapsed)
        }

        let prefix = trimmedPrefix(String(collapsed[..<openQuote]))
        let title = String(collapsed[collapsed.index(after: openQuote)..<closeQuote])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return PetSpeechBubbleTextParts(prefix: nil, threadTitle: nil, summary: collapsed)
        }

        let suffixStart = collapsed.index(after: closeQuote)
        let suffix = trimmedSuffix(String(collapsed[suffixStart...]))
        return PetSpeechBubbleTextParts(
            prefix: prefix,
            threadTitle: title,
            summary: suffix.isEmpty ? collapsed : suffix
        )
    }

    private static func trimmedPrefix(_ rawPrefix: String) -> String? {
        let trimmed = rawPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutTrailingComma = trimmed.hasSuffix("、") ? String(trimmed.dropLast()) : trimmed
        return withoutTrailingComma.isEmpty ? nil : withoutTrailingComma
    }

    private static func trimmedSuffix(_ rawSuffix: String) -> String {
        var suffix = rawSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        let separators: Set<Character> = ["は", ":", "：", "-", " "]
        while let first = suffix.first, separators.contains(first) {
            suffix.removeFirst()
            suffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return suffix
    }
}
