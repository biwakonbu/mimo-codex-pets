import Foundation

enum CodexAmbientTextSafety {
    static func isUnsafeForAmbientDisplay(_ text: String) -> Bool {
        looksLikeInstructionText(text) ||
            looksLikeMachinePayload(text) ||
            containsSensitiveFragment(text)
    }

    static func looksLikeInstructionText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
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

    static func looksLikeMachinePayload(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) && trimmed.contains(":") {
            return true
        }
        if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") {
            return true
        }

        let payloadMarkers = [
            "\"bundle_id\"",
            "\"element_id\"",
            "\"window_id\"",
            "\"question\"",
            "\"coordinate\"",
            "\"arguments\"",
            "\"method\"",
            "\"stdout\"",
            "\"stderr\"",
            "\"env\"",
            "bundle_id:",
            "element_id:",
            "window_id:",
            "arguments:",
            "method:",
            "stdout:",
            "stderr:",
            "env:"
        ]
        return payloadMarkers.contains { trimmed.contains($0) }
    }

    static func containsSensitiveFragment(_ text: String) -> Bool {
        let lowercased = text.lowercased()
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
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }
}
