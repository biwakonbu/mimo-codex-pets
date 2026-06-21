import Foundation

public enum CodexSessionSummarizer {
    public static func summary(from text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        guard !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(collapsed) else { return nil }

        let lowercased = collapsed.lowercased()
        if containsAny(lowercased, ["吹き出し", "bubble"]) &&
            containsAny(lowercased, ["要約", "summary", "会話", "セッション", "状況", "説明"]) {
            if containsAny(lowercased, ["具体", "考察", "進捗", "どんな事", "何を"]) {
                return "吹き出し要約の具体説明"
            }
            if containsAny(lowercased, ["作業内容", "内容"]) {
                return "作業内容の説明"
            }
            if containsAny(lowercased, ["セッションごと", "スレッドごと", "thread", "複数"]) {
                return "セッション別の状況整理"
            }
            if containsAny(lowercased, ["実装", "修正", "改善", "対応", "作る"]) {
                return "吹き出し要約の実装"
            }
            if containsAny(lowercased, ["表示", "文言", "ui"]) {
                return "吹き出し要約の表示文言"
            }
            if containsAny(lowercased, ["状況"]) {
                return "吹き出し要約の状況説明"
            }
            return "吹き出し要約"
        }
        if containsAny(lowercased, ["具体", "考察", "進捗", "どんな事", "何を"]) &&
            containsAny(lowercased, ["説明", "伝え", "表示", "欲しい", "ほしい"]) {
            return "進捗の具体説明"
        }
        if containsAny(lowercased, ["作業内容"]) &&
            containsAny(lowercased, ["説明", "要約", "表示", "伝え", "進め"]) {
            return "作業内容の説明"
        }
        if containsAny(lowercased, ["複数スレッド", "マルチスレッド", "multi-thread", "同時"]) &&
            containsAny(lowercased, ["吹き出し", "bubble", "表示", "thread"]) {
            return "複数セッション表示"
        }
        if containsAny(lowercased, ["codex"]) &&
            containsAny(lowercased, ["app-server", "接続", "通信", "protocol", "プロトコル", "thread/read"]) {
            return "Codex 連携"
        }
        if containsAny(lowercased, ["セッション", "session"]) &&
            containsAny(lowercased, ["状態", "内容", "情報", "進捗"]) {
            return "セッション状況"
        }
        if containsAny(lowercased, ["computer use", "accessibility", "productionSurface", "画面", "アクセシビリティ"]) {
            return "画面確認"
        }
        if containsAny(lowercased, ["ドラッグ", "drag"]) {
            return "ドラッグ移動"
        }
        if containsAny(lowercased, ["体力", "スタミナ", "stamina", "休憩", "速度", "tween", "移動", "自律"]) {
            return "Mimo の動き"
        }
        if containsAny(lowercased, ["透明", "透過", "ウィンドウ", "最前面", "白表示", "panel"]) {
            return "表示まわり"
        }
        if containsAny(lowercased, ["e2e", "qa", "テスト", "検証", "swift test"]) {
            return "検証"
        }
        if containsAny(lowercased, ["readme", "docs", "ドキュメント", "研究メモ", "仕様", "contract"]) {
            return "仕様整理"
        }
        if containsAny(lowercased, ["commit", "push", "git"]) {
            return "git 反映"
        }
        if containsAny(lowercased, ["mimo", "ペット"]) &&
            containsAny(lowercased, ["実装", "修正", "改善", "作る", "対応"]) {
            return "Mimo 改善"
        }
        if containsAny(lowercased, ["実装", "修正", "改善", "対応", "作る"]) {
            return "実装対応"
        }
        return nil
    }

    private static func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0.lowercased()) }
    }
}
