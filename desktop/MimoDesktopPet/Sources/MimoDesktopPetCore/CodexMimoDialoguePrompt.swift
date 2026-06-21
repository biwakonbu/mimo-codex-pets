import Foundation

public enum CodexMimoDialoguePrompt {
    public static let defaultModel = "gpt-5.4-mini"
    public static let defaultRefreshIntervalSeconds = 45.0
    public static let maxSpeechLength = 260

    public static let baseInstructions = """
    You write one short Japanese desktop-pet speech bubble for Mimo.
    Mimo is a tiny meeting-minutes AI assistant who gently reports Codex chat progress to the app user.
    Use only the sanitized chat fields supplied by the client. Do not infer hidden file paths, commands, logs, credentials, or private context.
    Output exactly one Japanese sentence, 80-180 characters.
    Include the chat name in Japanese corner quotes if it is supplied.
    Use the exact quote characters 「 and 」 for the chat name; do not use 『』.
    Explain what Codex is doing or thinking from the safe work topic and activity, not as raw internal status.
    Describe state naturally: 進めている, 返事を待っている, 確認してよさそう, ひと段落した, or つまずいた.
    Do not force ご主人. Use it only when Mimo is directly addressing the app user naturally.
    Sound warm and conversational, but do not add emoji, markdown, bullet points, or role labels.
    Never use the words スレッド, セッション, Thread, Session, or Codex Session in the output; say チャット instead.
    """

    public static func userInput(for line: CodexConversationLine) -> String {
        let title = displayTitle(line.threadTitle)
        let state = stateLabel(for: line.sessionState)
        let activity = activityLabel(for: line.activityKind)
        let topic = sanitized(line.workSummary ?? CodexSessionSummarizer.summary(from: line.text) ?? "作業内容")
        let deterministic = sanitized(CodexBubbleFormatter.bubbleText(for: line, limit: 96))

        return """
        Mimo speech request:
        chat_name: \(title)
        chat_state: \(state)
        activity_kind: \(activity)
        safe_work_topic: \(topic)
        deterministic_fallback: \(deterministic)

        Write Mimo's next speech bubble for the app user.
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
            .replacingOccurrences(of: "Codex Session", with: "このチャット")
            .replacingOccurrences(of: "Codex Thread", with: "このチャット")
            .replacingOccurrences(of: "スレッド", with: "チャット")
            .replacingOccurrences(of: "セッション", with: "チャット")
            .replacingOccurrences(of: "Session", with: "チャット")
            .replacingOccurrences(of: "session", with: "チャット")
            .replacingOccurrences(of: "Thread", with: "チャット")
            .replacingOccurrences(of: "thread", with: "チャット")
            .replacingOccurrences(
                of: #"「([^」]+)」は停止・レビュー可"#,
                with: #"「$1」は確認してよさそうだよ"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"「([^」]+)」はレビュー可能です"#,
                with: #"「$1」は確認してよさそうだよ"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"「([^」]+)」は動作中です"#,
                with: #"「$1」で作業を進めているよ"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"「([^」]+)」は動作中で"#,
                with: #"「$1」で作業を進めていて"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"「([^」]+)」は停止中です"#,
                with: #"「$1」はひと段落しているよ"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"停止・レビュー可\s*(?=「)"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "停止・レビュー可", with: "確認してよさそう")
            .replacingOccurrences(of: "動作中・", with: "")
            .replacingOccurrences(of: "停止・", with: "")
            .replacingOccurrences(of: "レビュー可能", with: "確認してよさそう")
            .replacingOccurrences(of: "レビュー可", with: "確認してよさそう")
            .replacingOccurrences(of: "レビューできます", with: "確認してよさそう")
            .replacingOccurrences(of: "動作中です", with: "作業を進めているよ")
            .replacingOccurrences(of: "動作中で", with: "作業を進めていて")
            .replacingOccurrences(of: "動作中", with: "作業中")
            .replacingOccurrences(of: "停止中です", with: "ひと段落しているよ")
            .replacingOccurrences(of: "停止中", with: "ひと段落")
            .replacingOccurrences(
                of: #"^ご主人[、,]\s*"#,
                with: "",
                options: .regularExpression
            )

        if text.hasPrefix("- ") {
            text.removeFirst(2)
        }
        guard !text.isEmpty else { return nil }
        guard !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(text) else { return nil }
        return CodexBubbleFormatter.compact(text, limit: maxSpeechLength)
    }

    private static func displayTitle(_ rawTitle: String) -> String {
        let title = CodexThreadTitleFormatter.title(
            from: [rawTitle],
            fallback: "このチャット",
            limit: 24
        )
        if ["Codex Thread", "Codex Session", "unknown-thread", "Codex"].contains(title) {
            return "このチャット"
        }
        return sanitized(title)
            .replacingOccurrences(of: "Codex Session", with: "このチャット")
            .replacingOccurrences(of: "Codex Thread", with: "このチャット")
            .replacingOccurrences(of: "スレッド", with: "チャット")
            .replacingOccurrences(of: "セッション", with: "チャット")
            .replacingOccurrences(of: "Session", with: "チャット")
            .replacingOccurrences(of: "session", with: "チャット")
            .replacingOccurrences(of: "Thread", with: "チャット")
            .replacingOccurrences(of: "thread", with: "チャット")
    }

    private static func stateLabel(for state: CodexSessionActivityState?) -> String {
        switch state {
        case .active:
            return "作業を進めている"
        case .waiting:
            return "返事や確認を待っている"
        case .stopped:
            return "ひと段落していて確認してよさそう"
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
            return "見直し"
        case .contextCompaction:
            return "文脈整理"
        case .skill:
            return "スキル確認"
        case .mention:
            return "参照確認"
        case .threadStatus:
            return "チャット状態"
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
