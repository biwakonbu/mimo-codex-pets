import Foundation

public enum CodexBubbleFormatter {
    public static func bubbleText(for line: CodexConversationLine, limit: Int = 46) -> String {
        let title = compactTitle(line.threadTitle)
        let summary = mimoSummary(for: line)
        return compact("ご主人、「\(title)」は\(summary)", limit: limit)
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

    private static func mimoSummary(for line: CodexConversationLine) -> String {
        let text = line.text.lowercased()

        if text.contains("失敗") || text.contains("エラー") || text.contains("failed") || text.contains("systemerror") {
            return "失敗を確認しました"
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
