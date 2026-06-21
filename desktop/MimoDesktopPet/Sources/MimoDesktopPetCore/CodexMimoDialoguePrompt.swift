import Foundation

public enum CodexMimoDialoguePrompt {
    public static let defaultModel = "gpt-5.4-mini"
    public static let defaultRefreshIntervalSeconds = 45.0
    public static let maxSpeechLength = 260

    public static let baseInstructions = """
    You write one short Japanese desktop-pet speech bubble for Mimo.
    Mimo is a tiny meeting-minutes AI assistant who gently reports Codex progress to ご主人.
    Use only the sanitized session fields supplied by the client. Do not infer hidden file paths, commands, logs, credentials, or private context.
    Output exactly one Japanese sentence, 80-180 characters, starting with ご主人、.
    Include the session/chat name in Japanese corner quotes if it is supplied.
    Use the exact quote characters 「 and 」 for the session/chat name; do not use 『』.
    Clearly say whether the session is 動作中, 確認待ち, 停止中, or 失敗.
    Sound warm and conversational, but do not add emoji, markdown, bullet points, or role labels.
    Never use the word スレッド in the output; say セッション or チャット instead.
    """

    public static func userInput(for line: CodexConversationLine) -> String {
        let title = displayTitle(line.threadTitle)
        let state = stateLabel(for: line.sessionState)
        let activity = activityLabel(for: line.activityKind)
        let topic = sanitized(line.workSummary ?? CodexSessionSummarizer.summary(from: line.text) ?? "作業内容")
        let deterministic = sanitized(CodexBubbleFormatter.bubbleText(for: line, limit: 96))

        return """
        Mimo speech request:
        session_name: \(title)
        session_state: \(state)
        activity_kind: \(activity)
        safe_work_topic: \(topic)
        deterministic_fallback: \(deterministic)

        Write Mimo's next speech bubble for ご主人.
        """
    }

    public static func cacheKey(for line: CodexConversationLine) -> String {
        [
            line.threadId,
            displayTitle(line.threadTitle),
            stateLabel(for: line.sessionState),
            line.activityKind.rawValue,
            sanitized(line.workSummary ?? ""),
            sanitized(line.text)
        ]
        .joined(separator: "|")
    }

    public static func sanitizedSpeech(from rawText: String) -> String? {
        var text = rawText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            .replacingOccurrences(of: "『", with: "「")
            .replacingOccurrences(of: "』", with: "」")
            .replacingOccurrences(of: "スレッド", with: "セッション")
            .replacingOccurrences(of: "Thread", with: "Session")
            .replacingOccurrences(of: "thread", with: "session")

        if text.hasPrefix("- ") {
            text.removeFirst(2)
        }
        guard !text.isEmpty else { return nil }
        guard !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(text) else { return nil }
        return CodexBubbleFormatter.compact(text, limit: maxSpeechLength)
    }

    private static func displayTitle(_ rawTitle: String) -> String {
        let title = CodexThreadTitleFormatter.title(
            from: [rawTitle, "Codex"],
            fallback: "Codex",
            limit: 24
        )
        return sanitized(title)
            .replacingOccurrences(of: "スレッド", with: "セッション")
            .replacingOccurrences(of: "Thread", with: "Session")
            .replacingOccurrences(of: "thread", with: "session")
    }

    private static func stateLabel(for state: CodexSessionActivityState?) -> String {
        switch state {
        case .active:
            return "動作中"
        case .waiting:
            return "確認待ち"
        case .stopped:
            return "停止中"
        case .failed:
            return "失敗"
        case nil:
            return "待機中"
        }
    }

    private static func activityLabel(for kind: CodexConversationActivityKind) -> String {
        switch kind {
        case .message:
            return "メッセージ確認"
        case .userRequest:
            return "依頼確認"
        case .assistantMessage:
            return "応答確認"
        case .plan:
            return "計画整理"
        case .reasoning:
            return "考えの整理"
        case .command:
            return "コマンド実行"
        case .test:
            return "テスト"
        case .fileChange:
            return "変更確認"
        case .fileRead:
            return "ファイル確認"
        case .tool:
            return "ツール確認"
        case .subAgent:
            return "別作業確認"
        case .webSearch, .search:
            return "調査"
        case .browser:
            return "ページ確認"
        case .image:
            return "画像確認"
        case .imageGeneration:
            return "画像作成"
        case .sleep:
            return "待機"
        case .review:
            return "レビュー"
        case .contextCompaction:
            return "文脈整理"
        case .skill:
            return "スキル確認"
        case .mention:
            return "参照確認"
        case .threadStatus:
            return "セッション状態"
        }
    }

    private static func sanitized(_ rawText: String) -> String {
        let compacted = rawText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(compacted) else {
            return "安全化済みの作業"
        }
        return CodexBubbleFormatter.compact(compacted, limit: 96)
    }
}
