import Foundation

public enum CodexThreadTitleFormatter {
    public static func title(from candidates: [Any?], fallback: String = "Codex Thread", limit: Int = 34) -> String {
        for candidate in candidates {
            guard let text = rawText(from: candidate) else { continue }
            let collapsed = text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !collapsed.isEmpty,
                  !looksLikeInstructionTitle(collapsed),
                  !looksUnsafeForAmbientDisplay(collapsed)
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

    private static func looksLikeInstructionTitle(_ title: String) -> Bool {
        let lowercased = title.lowercased()
        let blockedPrefixes = [
            "you are ",
            "knowledge cutoff",
            "current date",
            "<codex_internal_context",
            "# instructions",
            "system:"
        ]
        if blockedPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }

        let blockedFragments = [
            "treat it as the task",
            "higher-priority instructions",
            "do not reveal",
            "you are selected"
        ]
        return blockedFragments.contains { lowercased.contains($0) }
    }

    private static func looksUnsafeForAmbientDisplay(_ title: String) -> Bool {
        let lowercased = title.lowercased()
        let blockedFragments = [
            "://",
            "www.",
            "localhost:",
            "127.0.0.1",
            "/users/",
            "/private/",
            "/volumes/",
            "~/",
            "\\users\\",
            ".env",
            "credentials",
            "secret",
            "api_key",
            "apikey",
            "access token",
            "bearer ",
            "password"
        ]
        if blockedFragments.contains(where: { lowercased.contains($0) }) {
            return true
        }

        let blockedPatterns = [
            #"(?:^|\s)/(?:tmp|var|etc|opt|usr|bin|sbin)/"#,
            #"[A-Za-z]:\\"#,
            #"[A-Fa-f0-9]{32,}"#,
            #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        ]
        return blockedPatterns.contains { pattern in
            title.range(of: pattern, options: .regularExpression) != nil
        }
    }
}
