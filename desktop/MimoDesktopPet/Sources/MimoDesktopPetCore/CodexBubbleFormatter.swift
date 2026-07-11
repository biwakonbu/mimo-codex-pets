import Foundation

public enum CodexBubbleFormatter {
    public static func bubbleText(for line: CodexConversationLine, limit: Int = PetSpeechBubbleLayout.focusTextLimit) -> String {
        if let speech = line.mimoSpeech,
           !speech.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(speech) {
            return compact(
                displaySpeechVocabulary(speech),
                limit: max(limit, PetSpeechBubbleLayout.focusTextLimit * 2)
            )
        }
        let title = compactTitle(line.threadTitle)
        let summary = reportSummary(for: line, title: title)
        return compact("「\(title)」は\(primarySpeechSummary(summary, state: line.sessionState))", limit: limit)
    }

    public static func contextText(for line: CodexConversationLine, limit: Int = PetSpeechBubbleLayout.conversationTextLimit) -> String {
        let title = compactTitle(line.threadTitle, limit: PetSpeechBubbleLayout.chatTitleTextLimit)
        if let speech = line.mimoSpeech,
           !speech.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(speech) {
            let displaySpeech = displaySpeechVocabulary(speech)
            let parts = PetSpeechBubbleTextParts.parse(displaySpeech)
            let summary = parts.threadTitle == nil ? displaySpeech : parts.summary
            if !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return compact("「\(title)」\(summary)", limit: limit)
            }
        }
        let summary = compactSummary(for: mimoSummary(for: line), topic: reportTopic(for: line, title: title))
        return compact("「\(title)」\(contextDisplaySummary(summary))", limit: limit)
    }

    public static func statusSpeechText(for text: String) -> String {
        let cleaned = displaySpeechVocabulary(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }
        if isAlreadySpoken(cleaned) {
            return cleaned
        }

        let lowered = cleaned.lowercased()
        if lowered.contains("接続待ち") || lowered.contains("つながる") {
            return CodexMimoStatusSpeech.connecting
        }
        if lowered.contains("途切れ") || lowered.contains("切断") || lowered.contains("disconnect") {
            return CodexMimoStatusSpeech.disconnected
        }
        if lowered.contains("timeout") || lowered.contains("タイムアウト") || lowered.contains("遅い") {
            return CodexMimoStatusSpeech.timedOut
        }
        if lowered.contains("失敗") || lowered.contains("エラー") || lowered.contains("failed") || lowered.contains("systemerror") {
            return CodexMimoStatusSpeech.failed
        }
        if lowered.contains("確認待ち") || lowered.contains("入力待ち") || lowered.contains("承認") {
            return CodexMimoStatusSpeech.waiting
        }
        if lowered.contains("レビュー") || lowered.contains("確認してよさそう") || lowered.contains("完了") || lowered.contains("停止") {
            return CodexMimoStatusSpeech.review
        }
        if lowered.contains("待機") || lowered == "idle" {
            return CodexMimoStatusSpeech.idle
        }
        if lowered.contains("作業中") || lowered.contains("動作中") || lowered.contains("実行") ||
            lowered.contains("検証") || lowered.contains("応答") || lowered.contains("計画") {
            return CodexMimoStatusSpeech.active
        }
        return contextSentence(cleaned)
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

    private static func compactTitle(_ title: String, limit: Int = PetSpeechBubbleLayout.chatTitleTextLimit) -> String {
        let compacted = CodexThreadTitleFormatter.title(
            from: [title],
            fallback: "このチャット",
            limit: limit
        )
        if ["Codex Thread", "Codex Session", "unknown-thread", "Codex"].contains(compacted) {
            return "このチャット"
        }
        return compacted.isEmpty ? "このチャット" : displayTitleVocabulary(compacted)
    }

    private static func displayTitleVocabulary(_ title: String) -> String {
        title
            .replacingOccurrences(of: "Codex Session", with: "このチャット")
            .replacingOccurrences(of: "Codex Thread", with: "このチャット")
            .replacingOccurrences(of: "スレッド", with: "チャット")
            .replacingOccurrences(of: "セッション", with: "チャット")
            .replacingOccurrences(of: "Session", with: "チャット")
            .replacingOccurrences(of: "session", with: "チャット")
            .replacingOccurrences(of: "Thread", with: "チャット")
            .replacingOccurrences(of: "thread", with: "チャット")
    }

    private static func displaySpeechVocabulary(_ speech: String) -> String {
        displayStatusVocabulary(displayTitleVocabulary(speech))
            .replacingOccurrences(
                of: #"チャット状態:\s*"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"Codex の[^。！？]{1,30}をMimoも追いかけてるね"#,
                with: "Mimoもそっと見守ってるよ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"^ご主人[、,]\s*"#,
                with: "",
                options: .regularExpression
            )
    }

    private static func displayStatusVocabulary(_ text: String) -> String {
        text
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
                of: #"「([^」]+)」は確認待ちです"#,
                with: #"「$1」は確認を待っているよ"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"「([^」]+)」は確認待ち"#,
                with: #"「$1」は確認を待っているよ"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"「([^」]+)」は作業中です"#,
                with: #"「$1」で作業を進めているよ"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"「([^」]+)」は作業中"#,
                with: #"「$1」で作業を進めているよ"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"「([^」]+)」は待機中です"#,
                with: #"「$1」は少し待っているよ"#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"「([^」]+)」は待機中"#,
                with: #"「$1」は少し待っているよ"#,
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
            .replacingOccurrences(of: "確認待ちです", with: "確認を待っているよ")
            .replacingOccurrences(of: "待機中です", with: "少し待っているよ")
            .replacingOccurrences(of: "作業中です", with: "作業を進めているよ")
            .replacingOccurrences(of: "動作中です", with: "作業を進めているよ")
            .replacingOccurrences(of: "動作中で", with: "作業を進めていて")
            .replacingOccurrences(of: "動作中", with: "作業中")
            .replacingOccurrences(of: "停止中です", with: "ひと段落しているよ")
            .replacingOccurrences(of: "停止中", with: "ひと段落")
    }

    private static func compactSummary(for summary: String, topic: String? = nil) -> String {
        if let topic {
            switch summary {
            case "失敗を確認しました":
                return topicMentionsOutcome(topic, terms: ["失敗", "エラー", "つまずき", "問題"]) ? topic : "\(topic)つまずき"
            case "レビューできます":
                return topicMentionsOutcome(topic, terms: ["ひと段落", "確認してよさそう", "完了", "レビュー"]) ? topic : "\(topic)ひと段落"
            case "レビュー中です":
                return "\(topic)見直し中"
            case "確認待ちです":
                return topicMentionsOutcome(topic, terms: ["確認待ち", "返事待ち", "待ち", "入力待ち", "承認待ち"]) ? topic : "\(topic)返事待ち"
            case "依頼を確認しました":
                return "\(topic)依頼確認"
            case "応答をまとめています":
                return "\(topic)応答中"
            case "計画を整理中です":
                return "\(topic)計画中"
            case "文脈を整理中です":
                return "\(topic)文脈整理"
            case "文脈を整理しました":
                return "\(topic)文脈済み"
            case "考えを整理中です":
                return "\(topic)考察中"
            case "ツールで確認中です":
                return "\(topic)ツール確認"
            case "端末入力を確認中です":
                return "\(topic)端末確認"
            case "コマンドを実行中です":
                return "\(topic)実行中"
            case "承認を確認中です":
                return "\(topic)承認確認"
            case "承認を確認しました":
                return "\(topic)承認済み"
            case "フックを確認中です":
                return "\(topic)フック確認"
            case "フックを確認しました":
                return "\(topic)フック済み"
            case "確認を反映中です":
                return "\(topic)確認反映"
            case "目標を確認中です":
                return "\(topic)目標確認"
            case "目標を整理しました":
                return "\(topic)目標済み"
            case "モデルを調整中です":
                return "\(topic)モデル調整"
            case "モデルを確認中です":
                return "\(topic)モデル確認"
            case "安全を確認中です":
                return "\(topic)安全確認"
            case "問題を確認中です":
                return "\(topic)問題確認"
            case "警告を確認中です":
                return "\(topic)警告確認"
            case "安全警告を確認中です":
                return "\(topic)安全警告"
            case "MCP を確認中です":
                return "\(topic)MCP 確認"
            case "テストを実行中です":
                return "\(topic)テスト中"
            case "検証中です":
                return "\(topic)検証中"
            case "ファイルを確認中です":
                return "\(topic)ファイル確認"
            case "変更を反映中です":
                return "\(topic)反映中"
            case "差分を確認中です":
                return "\(topic)差分確認"
            case "調査中です":
                return "\(topic)調査中"
            case "作業を進めています":
                return "\(topic)中"
            case "進捗を確認しました":
                return "\(topic)進捗あり"
            case "更新を確認しました":
                return "\(topic)確認"
            default:
                break
            }
        }

        switch summary {
        case "失敗を確認しました":
            return "つまずきあり"
        case "レビュー中です":
            return "見直し中"
        case "レビューを終えました":
            return "見直し済み"
        case "文脈を整理中です":
            return "文脈整理"
        case "文脈を整理しました":
            return "文脈整理済み"
        case "考えを整理中です":
            return "考察中"
        case "モデルを調整中です":
            return "モデル調整"
        case "モデルを確認中です":
            return "モデル確認"
        case "安全を確認中です":
            return "安全確認"
        case "安全警告を確認中です":
            return "安全警告"
        case "問題を確認中です":
            return "問題確認"
        case "警告を確認中です":
            return "警告確認"
        case "MCP を確認中です":
            return "MCP 確認"
        case "別作業を確認中です":
            return "別作業確認"
        case "スキルを確認中です":
            return "スキル確認"
        case "ページを確認中です":
            return "ページ確認"
        case "ファイルを確認中です":
            return "ファイル確認"
        case "調査中です":
            return "調査中"
        case "画像を作成中です":
            return "画像作成中"
        case "画像を確認中です":
            return "画像確認"
        case "レビューできます":
            return "ひと段落"
        case "テストを実行中です":
            return "テスト中"
        case "ツールで確認中です":
            return "ツール確認"
        case "少し待機しています":
            return "待機中"
        case "変更を反映中です":
            return "変更反映"
        case "差分を確認中です":
            return "差分確認"
        case "承認を確認中です":
            return "承認確認"
        case "承認を確認しました":
            return "承認確認済み"
        case "フックを確認中です":
            return "フック確認"
        case "フックを確認しました":
            return "フック確認済み"
        case "確認を反映中です":
            return "確認反映"
        case "目標を確認中です":
            return "目標確認"
        case "目標を整理しました":
            return "目標整理済み"
        case "端末入力を確認中です":
            return "端末確認"
        case "コマンドを実行中です":
            return "実行中"
        case "作業中です":
            return "進めてる"
        case "参照を確認中です":
            return "参照確認"
        case "依頼を確認しました":
            return "依頼確認"
        case "確認待ちです":
            return "返事待ち"
        case "応答をまとめています":
            return "応答中"
        case "計画を整理中です":
            return "計画中"
        case "検証中です":
            return "検証中"
        case "作業を進めています":
            return "作業中"
        case "進捗を確認しました":
            return "進捗あり"
        case "更新を確認しました":
            return "更新あり"
        default:
            return summary
                .replacingOccurrences(of: "しています", with: "中")
                .replacingOccurrences(of: "しました", with: "済み")
                .replacingOccurrences(of: "です", with: "")
        }
    }

    private static func topicMentionsOutcome(_ topic: String, terms: [String]) -> Bool {
        let normalizedTopic = topic
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        return terms.contains { term in
            let normalizedTerm = term
                .lowercased()
                .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            return normalizedTopic.contains(normalizedTerm)
        }
    }

    private static func primarySpeechSummary(
        _ summary: String,
        state: CodexSessionActivityState?
    ) -> String {
        switch state {
        case .waiting:
            if summary.contains("確認待ち") || summary.contains("承認") {
                return spokenSummary(summary)
            }
            return waitingSpeechSummary(from: spokenSummary(summary))
        case .failed:
            if summary.contains("失敗") || summary.contains("問題") || summary.contains("警告") {
                return spokenSummary(summary)
            }
            return "つまずいたところを見つけたよ"
        case .stopped:
            if summary == "レビューできます" {
                return stoppedSpeechSummary("確認してよさそうだよ")
            }
            if summary == "作業を進めています" || summary == "更新を確認しました" {
                return stoppedSpeechSummary("ここまで進んでいるよ")
            }
            return stoppedSpeechSummary(spokenSummary(summary))
        case .active, nil:
            return spokenSummary(summary)
        }
    }

    private static func stoppedSpeechSummary(_ speech: String) -> String {
        guard !speech.contains("チャットを閉じ") else { return speech }
        let punctuation = speech.hasSuffix("。") || speech.hasSuffix("！") || speech.hasSuffix("？") ? "" : "。"
        return "\(speech)\(punctuation)確認後はチャットを閉じて、続きがあれば再開してね"
    }

    private static func spokenSummary(_ summary: String) -> String {
        switch summary {
        case "失敗を確認しました":
            return "つまずいたところを見つけたよ"
        case "レビューできます":
            return "確認してよさそうだよ"
        case "確認待ちです":
            return "確認を待っているよ"
        case "作業中です":
            return "作業を進めているよ"
        case "少し待機しています":
            return "少し待っているよ"
        case "進捗を確認しました":
            return "進捗を見つけたよ"
        case "更新を確認しました":
            return "更新を見つけたよ"
        default:
            return summary
                .replacingOccurrences(of: "レビューできます", with: "確認してよさそうだよ")
                .replacingOccurrences(of: "レビュー可能", with: "確認してよさそう")
                .replacingOccurrences(of: "レビュー可", with: "確認してよさそう")
                .replacingOccurrences(of: "確認待ちです", with: "確認を待っているよ")
                .replacingOccurrences(of: "失敗を確認しました", with: "つまずいたところを見つけたよ")
                .replacingOccurrences(of: "しています", with: "しているよ")
                .replacingOccurrences(of: "ています", with: "ているよ")
                .replacingOccurrences(of: "しました", with: "したよ")
                .replacingOccurrences(of: "できます", with: "できるよ")
                .replacingOccurrences(of: "中です", with: "中だよ")
                .replacingOccurrences(of: "です", with: "だよ")
        }
    }

    private static func withoutTerminalYo(_ text: String) -> String {
        text.hasSuffix("よ") ? String(text.dropLast()) : text
    }

    private static func waitingSpeechSummary(from spokenSummary: String) -> String {
        var text = withoutTerminalYo(spokenSummary)
        if text.hasSuffix("だ") {
            text.removeLast()
            return "\(text)で、確認を待っているよ"
        }
        return "\(text)。確認を待っているよ"
    }

    private static func contextDisplaySummary(_ summary: String) -> String {
        let spoken = summary
            .replacingOccurrences(of: "レビュー可能", with: "ひと段落")
            .replacingOccurrences(of: "レビュー可", with: "ひと段落")
            .replacingOccurrences(of: "確認してよさそう", with: "ひと段落")
            .replacingOccurrences(of: "失敗あり", with: "つまずきがある")
            .replacingOccurrences(of: "失敗", with: "つまずき")
            .replacingOccurrences(of: "確認待ち", with: "返事待ち")
            .replacingOccurrences(of: "作業中", with: "進めてる")
            .replacingOccurrences(of: "実行中", with: "実行してる")
            .replacingOccurrences(of: "応答中", with: "応答してる")
            .replacingOccurrences(of: "計画中", with: "計画してる")
            .replacingOccurrences(of: "考察中", with: "考えてる")
            .replacingOccurrences(of: "調査中", with: "調べてる")
            .replacingOccurrences(of: "検証中", with: "検証してる")
            .replacingOccurrences(of: "テスト中", with: "テストしてる")
            .replacingOccurrences(of: "反映中", with: "反映してる")
            .replacingOccurrences(of: "確認中", with: "確認してる")
            .replacingOccurrences(of: "進捗あり", with: "進捗がある")
            .replacingOccurrences(of: "更新あり", with: "更新がある")
            .replacingOccurrences(of: "待機中", with: "待ってる")
        return contextSentence(spoken)
    }

    private static func isAlreadySpoken(_ text: String) -> Bool {
        text.hasSuffix("よ") ||
            text.hasSuffix("ね") ||
            text.hasSuffix("みたい") ||
            text.hasSuffix("してる") ||
            text.hasSuffix("している") ||
            text.hasSuffix("待ってる")
    }

    private static func contextSentence(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        if text.hasSuffix("よ") || text.hasSuffix("ね") {
            return text
        }
        if text.hasSuffix("てる") || text.hasSuffix("ある") {
            return "\(text)よ"
        }
        if text.hasSuffix("確認") {
            return "\(text)してるよ"
        }
        return "\(text)だよ"
    }

    private static func mimoSummary(for line: CodexConversationLine) -> String {
        let text = line.text.lowercased()

        if text.contains("失敗") || text.contains("エラー") || text.contains("failed") || text.contains("systemerror") {
            return "失敗を確認しました"
        }
        if text.contains("確認してよさそう") || text.contains("ひと段落") {
            return "レビューできます"
        }
        if let summary = activitySummary(for: line.activityKind, text: text) {
            return summary
        }
        if text.contains("レビューを開始") {
            return "レビュー中です"
        }
        if text.contains("レビューを終了") {
            return "レビューを終えました"
        }
        if text.contains("承認確認済み") {
            return "承認を確認しました"
        }
        if text.contains("承認") {
            return "承認を確認中です"
        }
        if text.contains("フック") {
            if text.contains("確認済み") || text.contains("完了") {
                return "フックを確認しました"
            }
            return "フックを確認中です"
        }
        if text.contains("問題") {
            return "問題を確認中です"
        }
        if text.contains("安全警告") {
            return "安全警告を確認中です"
        }
        if text.contains("警告") {
            return "警告を確認中です"
        }
        if text.contains("安全") {
            return "安全を確認中です"
        }
        if text.contains("モデル") {
            if text.contains("確認") {
                return "モデルを確認中です"
            }
            return "モデルを調整中です"
        }
        if text.contains("mcp") {
            return "MCP を確認中です"
        }
        if text.contains("確認を反映") {
            return "確認を反映中です"
        }
        if text.contains("目標") {
            if text.contains("整理済み") || text.contains("解除") || text.contains("clear") {
                return "目標を整理しました"
            }
            return "目標を確認中です"
        }
        if text.contains("文脈") {
            return "文脈を整理中です"
        }
        if text.contains("サブエージェント") {
            return "別作業を確認中です"
        }
        if text.contains("スキル") {
            return "スキルを確認中です"
        }
        if text.contains("ページ") {
            return "ページを確認中です"
        }
        if text.contains("web 検索") || text.contains("検索") || text.contains("調査") {
            return "調査中です"
        }
        if text.contains("画像を生成") || text.contains("画像生成") {
            return "画像を作成中です"
        }
        if text.contains("画像") {
            return "画像を確認中です"
        }
        if text.contains("レビュー") || text.contains("完了") || text.contains("通っています") || text.contains("できる状態") {
            return "レビューできます"
        }
        if line.speaker == "tool" {
            return toolSummary(for: text)
        }
        if line.speaker == "you" {
            return "依頼を確認しました"
        }
        if text.contains("待ち") || text.contains("待って") || text.contains("入力") || text.contains("確認が必要") {
            return "確認待ちです"
        }
        if text.contains("応答") || text.contains("返答") {
            return "応答をまとめています"
        }
        if text.contains("計画") || text.contains("プラン") {
            return "計画を整理中です"
        }
        if text.contains("テスト") || text.contains("検証") || text.contains("qa") {
            return "検証中です"
        }
        if text.contains("実装") || text.contains("修正") || text.contains("作業") || text.contains("調整") || text.contains("移動") {
            return "作業を進めています"
        }
        if line.isAssistant {
            return "進捗を確認しました"
        }
        return "更新を確認しました"
    }

    private static func reportSummary(for line: CodexConversationLine, title: String) -> String {
        let summary = mimoSummary(for: line)
        guard let topic = reportTopic(for: line, title: title) else {
            return summary
        }

        switch summary {
        case "失敗を確認しました":
            return "\(topic)で失敗を確認しました"
        case "レビューできます":
            return "\(topic)を確認してよさそうです"
        case "レビュー中です":
            return "\(topic)を見直し中です"
        case "確認待ちです":
            return "\(topic)で確認待ちです"
        case "依頼を確認しました":
            return "\(topic)の依頼を確認しました"
        case "応答をまとめています":
            return "\(topic)をまとめています"
        case "計画を整理中です":
            return "\(topic)を計画中です"
        case "文脈を整理中です":
            return "\(topic)の文脈整理中です"
        case "文脈を整理しました":
            return "\(topic)の文脈整理済みです"
        case "考えを整理中です":
            return "\(topic)について考えを整理中です"
        case "ツールで確認中です":
            return "\(topic)をツールで確認中です"
        case "端末入力を確認中です":
            return "\(topic)で端末入力を確認中です"
        case "コマンドを実行中です":
            return "\(topic)でコマンドを実行中です"
        case "承認を確認中です":
            return "\(topic)の承認を確認中です"
        case "承認を確認しました":
            return "\(topic)の承認を確認しました"
        case "フックを確認中です":
            return "\(topic)のフックを確認中です"
        case "フックを確認しました":
            return "\(topic)のフックを確認しました"
        case "確認を反映中です":
            return "\(topic)の確認を反映中です"
        case "目標を確認中です":
            return "\(topic)の目標を確認中です"
        case "目標を整理しました":
            return "\(topic)の目標を整理済みです"
        case "モデルを調整中です":
            return "\(topic)のモデルを調整中です"
        case "モデルを確認中です":
            return "\(topic)のモデルを確認中です"
        case "安全を確認中です":
            return "\(topic)の安全を確認中です"
        case "問題を確認中です":
            return "\(topic)の問題を確認中です"
        case "警告を確認中です":
            return "\(topic)の警告を確認中です"
        case "安全警告を確認中です":
            return "\(topic)の安全警告を確認中です"
        case "MCP を確認中です":
            return "\(topic)のMCPを確認中です"
        case "テストを実行中です":
            return "\(topic)をテスト中です"
        case "検証中です":
            return "\(topic)を検証中です"
        case "ファイルを確認中です":
            return "\(topic)のファイル確認中です"
        case "変更を反映中です":
            return "\(topic)を反映中です"
        case "差分を確認中です":
            return "\(topic)の差分確認中です"
        case "調査中です":
            return "\(topic)を調査中です"
        case "作業を進めています":
            return "\(topic)を進めています"
        case "進捗を確認しました":
            return "\(topic)の進捗があります"
        case "更新を確認しました":
            return "\(topic)を確認しました"
        default:
            return summary
        }
    }

    private static func reportTopic(for line: CodexConversationLine, title: String) -> String? {
        let inferred = shouldInferReportTopic(from: line) ? CodexSessionSummarizer.summary(from: line.text) : nil
        let topic = line.workSummary ?? inferred
        guard let topic, !isRedundant(topic: topic, title: title) else {
            return nil
        }
        return topic
    }

    private static func shouldInferReportTopic(from line: CodexConversationLine) -> Bool {
        switch line.activityKind {
        case .message, .userRequest, .assistantMessage, .plan, .reasoning:
            return line.speaker != "tool"
        default:
            return false
        }
    }

    private static func isRedundant(topic: String, title: String) -> Bool {
        let normalizedTopic = topic
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        let normalizedTitle = title
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        guard !normalizedTopic.isEmpty, !normalizedTitle.isEmpty else {
            return false
        }
        return normalizedTitle.contains(normalizedTopic) || normalizedTopic.contains(normalizedTitle)
    }

    private static func activitySummary(
        for kind: CodexConversationActivityKind,
        text: String
    ) -> String? {
        switch kind {
        case .message, .assistantMessage, .threadStatus:
            return nil
        case .userRequest:
            return "依頼を確認しました"
        case .plan:
            return "計画を整理中です"
        case .reasoning:
            return "考えを整理中です"
        case .contextCompaction:
            if text.contains("済み") || text.contains("完了") {
                return "文脈を整理しました"
            }
            return "文脈を整理中です"
        case .command:
            if text.contains("端末") || text.contains("入力") {
                return "端末入力を確認中です"
            }
            return "コマンドを実行中です"
        case .test:
            return "テストを実行中です"
        case .fileChange:
            if text.contains("差分") {
                return "差分を確認中です"
            }
            return "変更を反映中です"
        case .fileRead:
            return "ファイルを確認中です"
        case .tool:
            if text.contains("フック") {
                if text.contains("確認済み") || text.contains("完了") {
                    return "フックを確認しました"
                }
                return "フックを確認中です"
            }
            if text.contains("mcp") {
                return "MCP を確認中です"
            }
            return "ツールで確認中です"
        case .subAgent:
            return "別作業を確認中です"
        case .webSearch, .search:
            return "調査中です"
        case .browser:
            return "ページを確認中です"
        case .image:
            return "画像を確認中です"
        case .imageGeneration:
            return "画像を作成中です"
        case .sleep:
            return "少し待機しています"
        case .review:
            if text.contains("承認確認済み") {
                return "承認を確認しました"
            }
            if text.contains("承認") {
                return "承認を確認中です"
            }
            if text.contains("終了") {
                return "レビューを終えました"
            }
            return "レビュー中です"
        case .skill:
            return "スキルを確認中です"
        case .mention:
            return "参照を確認中です"
        }
    }

    private static func toolSummary(for text: String) -> String {
        if text.contains("web 検索") || text.contains("検索") || text.contains("調査") {
            return "調査中です"
        }
        if text.contains("画像を生成") || text.contains("画像生成") {
            return "画像を作成中です"
        }
        if text.contains("画像") {
            return "画像を確認中です"
        }
        if text.contains("サブエージェント") {
            return "別作業を確認中です"
        }
        if text.contains("スキル") {
            return "スキルを確認中です"
        }
        if text.contains("ページ") {
            return "ページを確認中です"
        }
        if text.contains("待機") {
            return "少し待機しています"
        }
        if text.contains("テスト") || text.contains("検証") || text.contains("swift test") || text.contains("test") {
            return "テストを実行中です"
        }
        if text.contains("ツール") {
            return "ツールで確認中です"
        }
        if text.contains("ファイル") || text.contains("変更") {
            return "変更を反映中です"
        }
        if text.contains("実行") || text.contains("出力") || text.contains("command") {
            return "コマンドを実行中です"
        }
        return "作業中です"
    }
}
