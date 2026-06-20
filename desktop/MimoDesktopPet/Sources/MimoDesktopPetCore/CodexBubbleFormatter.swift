import Foundation

public enum CodexBubbleFormatter {
    public static func bubbleText(for line: CodexConversationLine, limit: Int = 42) -> String {
        let speaker = speakerLabel(for: line)
        return compact("\(speaker): \(line.text)", limit: limit)
    }

    public static func compact(_ text: String, limit: Int = 42) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return "" }
        guard collapsed.count > limit else { return collapsed }
        let index = collapsed.index(collapsed.startIndex, offsetBy: max(0, limit - 3))
        return String(collapsed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func speakerLabel(for line: CodexConversationLine) -> String {
        switch line.speaker {
        case "you":
            return "あなた"
        case "codex":
            return "Codex"
        case "tool":
            return "作業"
        case "thread":
            return "スレッド"
        default:
            return line.isAssistant ? "Codex" : "更新"
        }
    }
}
