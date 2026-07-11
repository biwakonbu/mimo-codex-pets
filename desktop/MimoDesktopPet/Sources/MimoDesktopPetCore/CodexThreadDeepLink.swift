import Foundation

public enum CodexThreadDeepLink {
    public static func url(for threadId: String) -> URL? {
        let trimmed = threadId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        guard let encodedThreadId = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "codex://threads/\(encodedThreadId)")
    }
}
