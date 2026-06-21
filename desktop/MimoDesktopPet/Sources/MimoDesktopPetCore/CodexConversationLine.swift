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
        case "plan":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                text: compactText(from: item["text"], limit: 64).map { "計画: \($0)" } ?? "計画を整理中"
            )
        case "reasoning":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                text: compactText(from: firstNonEmptyValue(item["summary"], item["content"]), limit: 64) ?? "考えを整理しています"
            )
        case "commandExecution":
            if itemFailed(item) {
                return makeLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: "tool",
                    isAssistant: true,
                    text: "コマンド実行に失敗"
                )
            }
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: commandActivityText(from: item["command"])
            )
        case "fileChange":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: itemFailed(item) ? "ファイル変更に失敗" : "ファイル変更を反映"
            )
        case "mcpToolCall":
            if itemFailed(item) {
                return makeLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: "tool",
                    isAssistant: true,
                    text: "ツール実行に失敗"
                )
            }
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "ツールを使用中"
            )
        case "dynamicToolCall":
            if itemFailed(item) {
                return makeLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: "tool",
                    isAssistant: true,
                    text: "ツール実行に失敗"
                )
            }
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "ツールを使用中"
            )
        case "collabAgentToolCall", "subAgentActivity":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: itemFailed(item) ? "サブエージェントに失敗" : "サブエージェントを確認中"
            )
        case "webSearch":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "Web 検索中"
            )
        case "openPage":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "ページを確認中"
            )
        case "findInPage":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "ページ内を検索中"
            )
        case "listFiles":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "ファイル一覧を確認中"
            )
        case "read":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "ファイルを確認中"
            )
        case "search":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "検索中"
            )
        case "imageView":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "画像を確認中"
            )
        case "image", "inputImage", "localImage":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "画像を確認中"
            )
        case "imageGeneration":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: itemFailed(item) ? "画像生成に失敗" : "画像を生成中"
            )
        case "sleep":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "少し待機中"
            )
        case "enteredReviewMode":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                text: "レビューを開始"
            )
        case "exitedReviewMode":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                text: "レビューを終了"
            )
        case "contextCompaction":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                text: "文脈を整理中"
            )
        case "skill":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                text: "スキルを確認中"
            )
        case "mention":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "thread",
                isAssistant: true,
                text: "参照を確認中"
            )
        case "hookPrompt":
            return nil
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
            speaker: ["agentMessageDelta", "planDelta", "turnPlanUpdated"].contains(kind) ? "codex" : "tool",
            text: progressText(for: kind),
            isAssistant: true
        )
    }

    public static func statusLine(
        threadId: String,
        threadTitle: String,
        threadStatus: CodexThreadStatus?,
        latestTurnStatus: CodexTurnStatus?,
        hasRecentAssistantFinal: Bool
    ) -> CodexConversationLine? {
        let text: String?
        if case .systemError = threadStatus {
            text = "失敗を確認"
        } else if latestTurnStatus == .failed {
            text = "失敗を確認"
        } else if case let .active(flags) = threadStatus {
            if flags.contains(.waitingOnApproval) || flags.contains(.waitingOnUserInput) {
                text = "確認待ち"
            } else {
                text = "作業中"
            }
        } else if latestTurnStatus == .inProgress {
            text = "作業中"
        } else if latestTurnStatus == .completed && hasRecentAssistantFinal {
            text = "レビュー可能"
        } else {
            text = nil
        }

        guard let text else { return nil }
        return CodexConversationLine(
            threadId: threadId,
            threadTitle: threadTitle,
            speaker: "thread",
            text: text,
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
        case "turnPlanUpdated":
            return "計画を更新中"
        case "reasoningDelta":
            return "文脈を整理中"
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
        guard !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(collapsed) else { return nil }
        if collapsed.count <= limit {
            return collapsed
        }
        let index = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func commandActivityText(from command: Any?) -> String {
        let raw = rawText(from: command)?.lowercased() ?? ""
        if raw.contains(" test") ||
            raw.hasSuffix("test") ||
            raw.contains("xctest") ||
            raw.contains("pytest") ||
            raw.contains("テスト") {
            return "テストを実行中"
        }
        return "コマンドを実行中"
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
            for key in ["text", "content", "message", "summary", "name", "title", "tool", "command"] {
                if let text = rawText(from: dict[key]), !text.isEmpty {
                    return text
                }
            }
        }
        return nil
    }

    private static func itemFailed(_ item: [String: Any]) -> Bool {
        guard let status = item["status"] as? String else { return false }
        return ["failed", "errored", "error"].contains(status)
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
