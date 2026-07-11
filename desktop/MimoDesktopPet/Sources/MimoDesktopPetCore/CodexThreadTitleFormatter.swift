import Foundation

public enum CodexThreadTitleFormatter {
    public static func title(from candidates: [Any?], fallback: String = "Codex Thread", limit: Int = 34) -> String {
        for candidate in candidates {
            guard let text = rawText(from: candidate) else { continue }
            let collapsed = text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !collapsed.isEmpty,
                  !isGenericInternalTitle(collapsed),
                  !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(collapsed)
            else { continue }
            guard collapsed.count > limit else { return collapsed }
            let index = collapsed.index(collapsed.startIndex, offsetBy: limit)
            return String(collapsed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return fallback
    }

    public static func isGenericInternalTitle(_ title: String) -> Bool {
        ["Codex Thread", "Codex Session", "unknown-thread", "Codex"].contains(
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    public static func title(
        fromThreadObject threadObject: [String: Any],
        fallback: String = "名前のないチャット",
        limit: Int = 34
    ) -> String {
        title(
            from: [
                threadObject["name"],
                threadObject["title"],
                threadObject["preview"],
                firstUserPrompt(in: threadObject)
            ],
            fallback: fallback,
            limit: limit
        )
    }

    private static func firstUserPrompt(in threadObject: [String: Any]) -> String? {
        guard let turns = threadObject["turns"] as? [[String: Any]] else { return nil }

        for turn in turns {
            if let input = rawText(from: turn["input"]), !input.isEmpty {
                return input
            }
            guard let items = turn["items"] as? [[String: Any]] else { continue }
            for item in items {
                let type = item["type"] as? String
                let role = item["role"] as? String
                guard type == "userMessage" || role == "user" else { continue }
                for key in ["content", "text", "message"] {
                    if let text = rawText(from: item[key]), !text.isEmpty {
                        return text
                    }
                }
            }
        }
        return nil
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
