import Foundation

public enum CodexThreadTitleFormatter {
    public static func title(from candidates: [Any?], fallback: String = "Codex Thread", limit: Int = 34) -> String {
        for candidate in candidates {
            guard let text = rawText(from: candidate) else { continue }
            let collapsed = text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !collapsed.isEmpty,
                  !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(collapsed)
            else { continue }
            guard collapsed.count > limit else { return collapsed }
            let index = collapsed.index(collapsed.startIndex, offsetBy: limit)
            return String(collapsed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return fallback
    }

    private static func rawText(from value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let strings = value as? [String] {
            return strings.joined(separator: " ")
        }
        if let array = value as? [Any] {
            return array.compactMap(rawText(from:)).joined(separator: " ")
        }
        if let dict = value as? [String: Any] {
            for key in ["name", "title", "preview", "text", "content", "message"] {
                if let text = rawText(from: dict[key]), !text.isEmpty {
                    return text
                }
            }
        }
        return nil
    }
}
