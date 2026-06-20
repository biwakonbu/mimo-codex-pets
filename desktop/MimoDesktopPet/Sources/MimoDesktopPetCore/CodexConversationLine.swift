import Foundation

public struct CodexConversationLine: Equatable, Sendable {
    public let threadId: String
    public let threadTitle: String
    public let speaker: String
    public let text: String
    public let isAssistant: Bool

    public init(
        threadId: String,
        threadTitle: String,
        speaker: String,
        text: String,
        isAssistant: Bool
    ) {
        self.threadId = threadId
        self.threadTitle = threadTitle
        self.speaker = speaker
        self.text = text
        self.isAssistant = isAssistant
    }
}

public enum CodexConversationExtractor {
    public static func lines(from threadObject: [String: Any], maxLines: Int = 6) -> [CodexConversationLine] {
        let threadId = threadObject["id"] as? String ?? "unknown-thread"
        let threadTitle = CodexThreadTitleFormatter.title(
            from: [
                threadObject["name"],
                threadObject["preview"],
                "Codex Thread"
            ]
        )

        var extracted: [CodexConversationLine] = []
        if let turns = threadObject["turns"] as? [[String: Any]] {
            for turn in turns {
                extracted.append(contentsOf: lines(fromTurn: turn, threadId: threadId, threadTitle: threadTitle))
            }
        }

        if extracted.isEmpty, let preview = compactText(from: threadObject["preview"], limit: 72) {
            extracted.append(
                CodexConversationLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: "thread",
                    text: preview,
                    isAssistant: false
                )
            )
        }

        return Array(extracted.suffix(max(0, maxLines)))
    }

    public static func line(from item: [String: Any], threadId: String, threadTitle: String) -> CodexConversationLine? {
        let type = item["type"] as? String

        switch type {
        case "userMessage":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "you",
                isAssistant: false,
                text: compactText(from: item["content"], limit: 68) ?? "ユーザー入力を受信"
            )
        case "agentMessage", "agent_message":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                text: compactText(from: firstNonEmptyValue(item["text"], item["content"]), limit: 76) ?? "応答を受信"
            )
        case "reasoning":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                text: compactText(from: item["summary"], limit: 64) ?? "考えを整理しています"
            )
        case "commandExecution":
            let commandText = compactText(from: item["command"], limit: 56)
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: commandText.map { "実行: \($0)" } ?? "コマンドを実行中"
            )
        case "fileChange":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "ファイル変更を反映"
            )
        case "mcpToolCall":
            let toolName = compactText(from: firstNonEmptyValue(item["tool"], item["toolName"], item["name"]), limit: 40)
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: toolName.map { "ツール: \($0)" } ?? "ツールを使用中"
            )
        default:
            if let role = item["role"] as? String {
                return makeLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: role == "assistant" ? "codex" : "you",
                    isAssistant: role == "assistant",
                    text: compactText(from: firstNonEmptyString(item["text"], item["content"], item["message"]), limit: 72)
                )
            }
            return nil
        }
    }

    public static func progressLine(
        threadId: String,
        threadTitle: String,
        kind: String
    ) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: threadTitle,
            speaker: kind == "agentMessageDelta" || kind == "planDelta" ? "codex" : "tool",
            text: progressText(for: kind),
            isAssistant: true
        )
    }

    private static func lines(fromTurn turn: [String: Any], threadId: String, threadTitle: String) -> [CodexConversationLine] {
        var lines: [CodexConversationLine] = []

        if let items = turn["items"] as? [[String: Any]] {
            for item in items {
                if let line = line(from: item, threadId: threadId, threadTitle: threadTitle) {
                    lines.append(line)
                }
            }
        }

        if lines.isEmpty, let input = compactText(from: turn["input"], limit: 68) {
            lines.append(
                CodexConversationLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: "you",
                    text: input,
                    isAssistant: false
                )
            )
        }

        if lines.isEmpty, let status = turn["status"] as? String {
            lines.append(
                CodexConversationLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: "turn",
                    text: status == "completed" ? "ターンが完了しました" : "ターン状態: \(status)",
                    isAssistant: true
                )
            )
        }

        return lines
    }

    private static func makeLine(
        threadId: String,
        threadTitle: String,
        speaker: String,
        isAssistant: Bool,
        text: String?
    ) -> CodexConversationLine? {
        guard let text, !text.isEmpty else { return nil }
        return CodexConversationLine(
            threadId: threadId,
            threadTitle: threadTitle,
            speaker: speaker,
            text: text,
            isAssistant: isAssistant
        )
    }

    private static func progressText(for kind: String) -> String {
        switch kind {
        case "agentMessageDelta":
            return "応答を作成中"
        case "planDelta":
            return "計画を整理中"
        case "commandExecutionOutputDelta":
            return "コマンド出力を確認中"
        case "fileChangeOutputDelta":
            return "ファイル変更を確認中"
        case "mcpToolCallProgress":
            return "ツールで確認中"
        default:
            return "進捗を確認中"
        }
    }

    private static func compactText(from value: Any?, limit: Int) -> String? {
        guard let raw = rawText(from: value) else { return nil }
        let collapsed = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        guard !looksLikeMachinePayload(collapsed) else { return nil }
        if collapsed.count <= limit {
            return collapsed
        }
        let index = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
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
            for key in ["text", "content", "message", "summary", "name", "title", "tool"] {
                if let text = rawText(from: dict[key]), !text.isEmpty {
                    return text
                }
            }
        }
        return nil
    }

    private static func looksLikeMachinePayload(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) && trimmed.contains(":") {
            return true
        }
        let payloadMarkers = [
            "\"bundle_id\"",
            "\"element_id\"",
            "\"window_id\"",
            "\"question\"",
            "\"coordinate\"",
            "\"arguments\"",
            "\"method\""
        ]
        return payloadMarkers.contains { trimmed.contains($0) }
    }

    private static func firstNonEmptyValue(_ values: Any?...) -> Any? {
        for value in values {
            if let text = rawText(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func firstNonEmptyString(_ values: Any?...) -> String {
        for value in values {
            if let text = rawText(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return text
            }
        }
        return ""
    }

}
