import Foundation

public enum CodexConversationActivityKind: String, Equatable, Sendable {
    case message
    case userRequest
    case assistantMessage
    case plan
    case reasoning
    case command
    case test
    case fileChange
    case fileRead
    case tool
    case subAgent
    case webSearch
    case browser
    case search
    case image
    case imageGeneration
    case sleep
    case review
    case contextCompaction
    case skill
    case mention
    case threadStatus
}

public struct CodexConversationLine: Equatable, Sendable {
    public let threadId: String
    public let threadTitle: String
    public let speaker: String
    public let text: String
    public let isAssistant: Bool
    public let activityKind: CodexConversationActivityKind
    public let workSummary: String?

    public init(
        threadId: String,
        threadTitle: String,
        speaker: String,
        text: String,
        isAssistant: Bool,
        activityKind: CodexConversationActivityKind = .message,
        workSummary: String? = nil
    ) {
        self.threadId = threadId
        self.threadTitle = threadTitle
        self.speaker = speaker
        self.text = text
        self.isAssistant = isAssistant
        self.activityKind = activityKind
        self.workSummary = workSummary
    }

    public func withWorkSummary(_ workSummary: String?) -> CodexConversationLine {
        guard self.workSummary != workSummary else { return self }
        return CodexConversationLine(
            threadId: threadId,
            threadTitle: threadTitle,
            speaker: speaker,
            text: text,
            isAssistant: isAssistant,
            activityKind: activityKind,
            workSummary: workSummary
        )
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
                    isAssistant: false,
                    activityKind: .message
                )
            )
        }

        return Array(propagatingWorkSummaries(in: extracted).suffix(max(0, maxLines)))
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
                activityKind: .userRequest,
                text: compactText(from: item["content"], limit: 68) ?? "ユーザー入力を受信"
            )
        case "agentMessage", "agent_message":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                activityKind: .assistantMessage,
                text: compactText(from: firstNonEmptyValue(item["text"], item["content"]), limit: 76) ?? "応答を受信"
            )
        case "plan":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                activityKind: .plan,
                text: compactText(from: item["text"], limit: 64).map { "計画: \($0)" } ?? "計画を整理中"
            )
        case "reasoning":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                activityKind: .reasoning,
                text: compactText(from: firstNonEmptyValue(item["summary"], item["content"]), limit: 64) ?? "考えを整理しています"
            )
        case "commandExecution":
            let commandActivity = commandActivity(from: item["command"])
            if itemFailed(item) {
                return makeLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: "tool",
                    isAssistant: true,
                    activityKind: commandActivity.kind,
                    text: "コマンド実行に失敗"
                )
            }
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: commandActivity.kind,
                text: commandActivity.text
            )
        case "fileChange":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .fileChange,
                text: itemFailed(item) ? "ファイル変更に失敗" : "ファイル変更を反映"
            )
        case "mcpToolCall":
            if itemFailed(item) {
                return makeLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: "tool",
                    isAssistant: true,
                    activityKind: .tool,
                    text: "ツール実行に失敗"
                )
            }
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .tool,
                text: "ツールを使用中"
            )
        case "dynamicToolCall":
            if itemFailed(item) {
                return makeLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: "tool",
                    isAssistant: true,
                    activityKind: .tool,
                    text: "ツール実行に失敗"
                )
            }
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .tool,
                text: "ツールを使用中"
            )
        case "collabAgentToolCall", "subAgentActivity":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .subAgent,
                text: itemFailed(item) ? "サブエージェントに失敗" : "サブエージェントを確認中"
            )
        case "webSearch":
            let activity = webSearchActivity(from: item["action"])
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: activity.kind,
                text: activity.text
            )
        case "openPage":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .browser,
                text: "ページを確認中"
            )
        case "findInPage":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .browser,
                text: "ページ内を検索中"
            )
        case "listFiles":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .fileRead,
                text: "ファイル一覧を確認中"
            )
        case "read":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .fileRead,
                text: "ファイルを確認中"
            )
        case "search":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .search,
                text: "検索中"
            )
        case "imageView":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .image,
                text: "画像を確認中"
            )
        case "image", "inputImage", "localImage":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .image,
                text: "画像を確認中"
            )
        case "imageGeneration":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .imageGeneration,
                text: itemFailed(item) ? "画像生成に失敗" : "画像を生成中"
            )
        case "sleep":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .sleep,
                text: "少し待機中"
            )
        case "enteredReviewMode":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                activityKind: .review,
                text: "レビューを開始"
            )
        case "exitedReviewMode":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                activityKind: .review,
                text: "レビューを終了"
            )
        case "contextCompaction":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "codex",
                isAssistant: true,
                activityKind: .contextCompaction,
                text: "文脈を整理中"
            )
        case "skill":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "tool",
                isAssistant: true,
                activityKind: .skill,
                text: "スキルを確認中"
            )
        case "mention":
            return makeLine(
                threadId: threadId,
                threadTitle: threadTitle,
                speaker: "thread",
                isAssistant: true,
                activityKind: .mention,
                text: "参照を確認中"
            )
        case "hookPrompt":
            return nil
        default:
            if let role = item["role"] as? String {
                let isAssistant = role == "assistant"
                let fallback = isAssistant ? "応答を受信" : "ユーザー入力を受信"
                return makeLine(
                    threadId: threadId,
                    threadTitle: threadTitle,
                    speaker: isAssistant ? "codex" : "you",
                    isAssistant: isAssistant,
                    activityKind: isAssistant ? .assistantMessage : .userRequest,
                    text: compactText(
                        from: firstNonEmptyString(item["text"], item["content"], item["message"]),
                        limit: 72
                    ) ?? fallback
                )
            }
            return nil
        }
    }

    public static func progressLine(
        threadId: String,
        threadTitle: String,
        kind: String,
        workSummary: String? = nil
    ) -> CodexConversationLine {
        CodexConversationLine(
            threadId: threadId,
            threadTitle: threadTitle,
            speaker: progressSpeaker(for: kind),
            text: progressText(for: kind),
            isAssistant: true,
            activityKind: progressActivityKind(for: kind),
            workSummary: workSummary
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
            isAssistant: true,
            activityKind: .threadStatus,
            workSummary: nil
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
                    isAssistant: false,
                    activityKind: .userRequest
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
                    isAssistant: true,
                    activityKind: .threadStatus
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
        activityKind: CodexConversationActivityKind,
        text: String?
    ) -> CodexConversationLine? {
        guard let text, !text.isEmpty else { return nil }
        let workSummary = shouldInferWorkSummary(for: activityKind, speaker: speaker)
            ? CodexSessionSummarizer.summary(from: text)
            : nil
        return CodexConversationLine(
            threadId: threadId,
            threadTitle: threadTitle,
            speaker: speaker,
            text: text,
            isAssistant: isAssistant,
            activityKind: activityKind,
            workSummary: workSummary
        )
    }

    private static func shouldInferWorkSummary(
        for activityKind: CodexConversationActivityKind,
        speaker: String
    ) -> Bool {
        switch activityKind {
        case .message, .userRequest, .assistantMessage, .plan, .reasoning:
            return speaker != "tool"
        default:
            return false
        }
    }

    private static func propagatingWorkSummaries(in lines: [CodexConversationLine]) -> [CodexConversationLine] {
        var latestWorkSummary: String?
        return lines.map { line in
            if let workSummary = line.workSummary {
                latestWorkSummary = workSummary
                return line
            }
            guard shouldInheritWorkSummary(line), let latestWorkSummary else {
                return line
            }
            return line.withWorkSummary(latestWorkSummary)
        }
    }

    private static func shouldInheritWorkSummary(_ line: CodexConversationLine) -> Bool {
        switch line.activityKind {
        case .command, .test, .fileChange, .fileRead, .tool, .subAgent,
             .webSearch, .browser, .search, .image, .imageGeneration,
             .sleep, .review, .contextCompaction, .skill, .mention,
             .threadStatus:
            return true
        case .message, .userRequest, .assistantMessage, .plan, .reasoning:
            return false
        }
    }

    private static func progressText(for kind: String) -> String {
        switch kind {
        case "agentMessageDelta":
            return "応答を作成中"
        case "planDelta":
            return "計画を整理中"
        case "turnPlanUpdated":
            return "計画を更新中"
        case "turnDiffUpdated":
            return "差分を確認中"
        case "threadCompacted":
            return "文脈を整理済み"
        case "modelRerouted":
            return "モデルを調整中"
        case "modelVerification":
            return "モデルを確認中"
        case "turnModerationMetadata":
            return "安全を確認中"
        case "reasoningDelta":
            return "文脈を整理中"
        case "commandExecutionOutputDelta":
            return "コマンド出力を確認中"
        case "commandExecutionTerminalInteraction":
            return "端末入力を確認中"
        case "fileChangeOutputDelta":
            return "ファイル変更を確認中"
        case "fileChangePatchUpdated":
            return "変更差分を確認中"
        case "mcpToolCallProgress":
            return "ツールで確認中"
        case "autoApprovalReviewStarted":
            return "承認を確認中"
        case "autoApprovalReviewCompleted":
            return "承認確認済み"
        case "hookStarted":
            return "フックを確認中"
        case "hookCompleted":
            return "フックを確認済み"
        case "serverRequestResolved":
            return "確認を反映中"
        case "threadGoalUpdated":
            return "目標を確認中"
        case "threadGoalCleared":
            return "目標を整理済み"
        case "error":
            return "問題を確認中"
        case "warning":
            return "警告を確認中"
        case "guardianWarning":
            return "安全警告を確認中"
        case "mcpServerStartupStatusUpdated":
            return "MCP を確認中"
        default:
            return "進捗を確認中"
        }
    }

    private static func progressSpeaker(for kind: String) -> String {
        switch kind {
        case "agentMessageDelta", "planDelta", "turnPlanUpdated":
            return "codex"
        case "threadGoalUpdated", "threadGoalCleared", "serverRequestResolved",
             "threadCompacted", "modelRerouted", "modelVerification",
             "turnModerationMetadata", "error", "warning", "guardianWarning":
            return "thread"
        case "mcpServerStartupStatusUpdated":
            return "tool"
        default:
            return "tool"
        }
    }

    private static func progressActivityKind(for kind: String) -> CodexConversationActivityKind {
        switch kind {
        case "agentMessageDelta":
            return .assistantMessage
        case "planDelta", "turnPlanUpdated":
            return .plan
        case "reasoningDelta":
            return .reasoning
        case "threadCompacted":
            return .contextCompaction
        case "commandExecutionOutputDelta", "commandExecutionTerminalInteraction":
            return .command
        case "fileChangeOutputDelta", "fileChangePatchUpdated", "turnDiffUpdated":
            return .fileChange
        case "autoApprovalReviewStarted", "autoApprovalReviewCompleted":
            return .review
        case "hookStarted", "hookCompleted", "mcpServerStartupStatusUpdated":
            return .tool
        case "mcpToolCallProgress":
            return .tool
        case "threadGoalUpdated", "threadGoalCleared", "serverRequestResolved",
             "modelRerouted", "modelVerification", "turnModerationMetadata",
             "error", "warning", "guardianWarning":
            return .threadStatus
        default:
            return .threadStatus
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

    private static func commandActivity(from command: Any?) -> (text: String, kind: CodexConversationActivityKind) {
        if let action = command as? [String: Any],
           let type = action["type"] as? String {
            switch type {
            case "read":
                return ("ファイルを確認中", .fileRead)
            case "listFiles":
                return ("ファイル一覧を確認中", .fileRead)
            case "search":
                return ("検索中", .search)
            default:
                break
            }
        }

        let raw = rawText(from: command)?.lowercased() ?? ""
        if raw.contains(" test") ||
            raw.hasSuffix("test") ||
            raw.contains("xctest") ||
            raw.contains("pytest") ||
            raw.contains("テスト") {
            return ("テストを実行中", .test)
        }
        return ("コマンドを実行中", .command)
    }

    private static func webSearchActivity(from action: Any?) -> (text: String, kind: CodexConversationActivityKind) {
        guard let action = action as? [String: Any],
              let type = action["type"] as? String
        else {
            return ("Web 検索中", .webSearch)
        }

        switch type {
        case "openPage":
            return ("ページを確認中", .browser)
        case "findInPage":
            return ("ページ内を検索中", .browser)
        case "search":
            return ("Web 検索中", .webSearch)
        default:
            return ("Web 操作を確認中", .webSearch)
        }
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
