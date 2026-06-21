import Foundation

public enum CodexBubbleFormatter {
    public static func bubbleText(for line: CodexConversationLine, limit: Int = 46) -> String {
        let title = compactTitle(line.threadTitle)
        let summary = mimoSummary(for: line)
        return compact("ご主人、「\(title)」は\(summary)", limit: limit)
    }

    public static func contextText(for line: CodexConversationLine, limit: Int = 34) -> String {
        let title = compactTitle(line.threadTitle, limit: 12)
        let summary = compactSummary(for: mimoSummary(for: line))
        return compact("「\(title)」\(summary)", limit: limit)
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

    private static func compactTitle(_ title: String, limit: Int = 16) -> String {
        let compacted = CodexThreadTitleFormatter.title(
            from: [title],
            fallback: "Codex Thread",
            limit: limit
        )
        if ["Codex Thread", "unknown-thread"].contains(compacted) {
            return "Codex"
        }
        return compacted.isEmpty ? "Codex" : compacted
    }

    private static func compactSummary(for summary: String) -> String {
        switch summary {
        case "失敗を確認しました":
            return "失敗"
        case "レビュー中です":
            return "レビュー中"
        case "レビューを終えました":
            return "レビュー完了"
        case "文脈を整理中です":
            return "文脈整理"
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
            return "レビュー可"
        case "テストを実行中です":
            return "テスト中"
        case "ツールで確認中です":
            return "ツール確認"
        case "少し待機しています":
            return "待機中"
        case "変更を反映中です":
            return "変更反映"
        case "コマンドを実行中です":
            return "実行中"
        case "作業中です":
            return "作業中"
        case "参照を確認中です":
            return "参照確認"
        case "依頼を確認しました":
            return "依頼確認"
        case "確認待ちです":
            return "確認待ち"
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

    private static func mimoSummary(for line: CodexConversationLine) -> String {
        let text = line.text.lowercased()

        if text.contains("失敗") || text.contains("エラー") || text.contains("failed") || text.contains("systemerror") {
            return "失敗を確認しました"
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
        case .reasoning, .contextCompaction:
            return "文脈を整理中です"
        case .command:
            return "コマンドを実行中です"
        case .test:
            return "テストを実行中です"
        case .fileChange:
            return "変更を反映中です"
        case .fileRead:
            return "ファイルを確認中です"
        case .tool:
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
