import Foundation

public enum PetSpeechBubblePaginator {
    public static func pages(
        for text: String,
        role: PetSpeechBubbleRole,
        limit: Int = 0
    ) -> [String] {
        let resolvedLimit = limit > 0 ? limit : PetSpeechBubbleLayout.textLimit(for: role)
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return [] }
        guard collapsed.count > resolvedLimit else { return [collapsed] }

        var remaining = collapsed
        var result: [String] = []
        while remaining.count > resolvedLimit {
            let split = splitIndex(in: remaining, limit: resolvedLimit)
            let page = String(remaining[..<split]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !page.isEmpty {
                result.append(page)
            }
            remaining = String(remaining[split...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !remaining.isEmpty {
            result.append(remaining)
        }
        return result.isEmpty ? [collapsed] : result
    }

    private static func splitIndex(in text: String, limit: Int) -> String.Index {
        let hardLimit = text.index(text.startIndex, offsetBy: min(limit, text.count))
        guard hardLimit < text.endIndex else { return text.endIndex }

        let preferredRange = text.startIndex..<hardLimit
        let preferredSeparators = CharacterSet(charactersIn: "。！？!?、，,;；:： ")
        var candidate = hardLimit

        var index = text.index(before: hardLimit)
        while index > text.startIndex {
            if String(text[index]).rangeOfCharacter(from: preferredSeparators) != nil {
                let distance = text.distance(from: text.startIndex, to: index)
                if distance >= max(24, Int(Double(limit) * 0.48)) {
                    candidate = text.index(after: index)
                    break
                }
            }
            index = text.index(before: index)
        }

        if candidate == hardLimit,
           let space = text.range(of: " ", options: .backwards, range: preferredRange),
           text.distance(from: text.startIndex, to: space.lowerBound) >= max(24, Int(Double(limit) * 0.48)) {
            candidate = space.upperBound
        }

        return candidate
    }
}
